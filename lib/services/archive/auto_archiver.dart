// lib/services/auto_archiver.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/stats/utils/op_day.dart'
    show monthRangeUtc, opDayKeyFromLocal;
import 'package:elfouad_admin/services/archive/archive_service.dart';
import 'package:elfouad_admin/services/archive/daily_archive_stats.dart'
    show syncDailyArchiveForDay;
import 'package:elfouad_admin/services/archive/monthly_archive_stats.dart'
    show syncMonthlyArchiveForMonth;
import 'package:shared_preferences/shared_preferences.dart';

const String _autoArchiveMetaCollection = 'meta';
const String _autoArchiveMetaDocId = 'auto_archive';
const String _autoArchiveDeviceIdPrefKey = 'auto_archive_device_id';
const String _autoArchiveOwnerField = 'owner_device_id';
const String _dailyArchiveRunningField = 'daily_archive_running';
const String _dailyArchiveRunningUntilField = 'daily_archive_running_until';
const String _dailyArchiveLastDayKeyField = 'daily_archive_last_day_key';

/// Runs daily archive for a specific already-closed operational day (4AM-based),
/// exactly once globally across devices, and only from owner device.
Future<bool> runDailyArchiveForClosedDayIfNeeded({
  required DateTime closedDayStartLocal,
  FirebaseFirestore? firestore,
  SharedPreferences? prefs,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final localPrefs = prefs ?? await SharedPreferences.getInstance();

  final isOwner = await isCurrentDeviceAutoArchiveOwner(
    firestore: db,
    prefs: localPrefs,
  );
  if (!isOwner) return false;

  final dayKey = opDayKeyFromLocal(closedDayStartLocal);
  final deviceId = await getOrCreateAutoArchiveDeviceId(prefs: localPrefs);
  final now = DateTime.now();
  final lockUntil = now.add(const Duration(minutes: 20));
  final metaRef = db
      .collection(_autoArchiveMetaCollection)
      .doc(_autoArchiveMetaDocId);

  final lockOk = await db.runTransaction((tx) async {
    final snap = await tx.get(metaRef);
    final data = snap.data();

    final ownerId = (data?[_autoArchiveOwnerField] ?? '').toString().trim();
    if (ownerId.isNotEmpty && ownerId != deviceId) {
      return false;
    }

    final lastDay = (data?[_dailyArchiveLastDayKeyField] ?? '')
        .toString()
        .trim();
    if (lastDay == dayKey) {
      return false;
    }

    final running = data?[_dailyArchiveRunningField] == true;
    final runningUntil = data?[_dailyArchiveRunningUntilField];
    if (running &&
        runningUntil is Timestamp &&
        runningUntil.toDate().isAfter(now)) {
      return false;
    }

    tx.set(metaRef, {
      if (ownerId.isEmpty) _autoArchiveOwnerField: deviceId,
      if (ownerId.isEmpty) 'owner_claimed_at': FieldValue.serverTimestamp(),
      _dailyArchiveRunningField: true,
      _dailyArchiveRunningUntilField: Timestamp.fromDate(lockUntil),
      'daily_archive_running_by': deviceId,
      'daily_archive_target_day': dayKey,
    }, SetOptions(merge: true));
    return true;
  });

  if (!lockOk) return false;

  try {
    await syncDailyArchiveForDay(firestore: db, dayLocal: closedDayStartLocal);

    await metaRef.set({
      _dailyArchiveLastDayKeyField: dayKey,
      'daily_archive_last_synced_at': FieldValue.serverTimestamp(),
      _dailyArchiveRunningField: false,
      _dailyArchiveRunningUntilField: FieldValue.delete(),
      'daily_archive_running_by': FieldValue.delete(),
      'daily_archive_target_day': FieldValue.delete(),
    }, SetOptions(merge: true));
    return true;
  } catch (_) {
    await metaRef.set({
      _dailyArchiveRunningField: false,
      _dailyArchiveRunningUntilField: FieldValue.delete(),
      'daily_archive_running_by': FieldValue.delete(),
      'daily_archive_target_day': FieldValue.delete(),
    }, SetOptions(merge: true));
    rethrow;
  }
}

Future<String> getOrCreateAutoArchiveDeviceId({
  SharedPreferences? prefs,
}) async {
  final localPrefs = prefs ?? await SharedPreferences.getInstance();
  final existing = localPrefs.getString(_autoArchiveDeviceIdPrefKey);
  if (existing != null && existing.trim().isNotEmpty) {
    return existing.trim();
  }
  final generated = _generateUuidV4();
  await localPrefs.setString(_autoArchiveDeviceIdPrefKey, generated);
  return generated;
}

Future<bool> isCurrentDeviceAutoArchiveOwner({
  FirebaseFirestore? firestore,
  SharedPreferences? prefs,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final localPrefs = prefs ?? await SharedPreferences.getInstance();
  final deviceId = await getOrCreateAutoArchiveDeviceId(prefs: localPrefs);
  final metaRef = db
      .collection(_autoArchiveMetaCollection)
      .doc(_autoArchiveMetaDocId);

  try {
    return await db.runTransaction((tx) async {
      final snap = await tx.get(metaRef);
      final data = snap.data();
      final ownerId = (data?[_autoArchiveOwnerField] ?? '').toString().trim();

      if (ownerId.isEmpty) {
        tx.set(metaRef, {
          _autoArchiveOwnerField: deviceId,
          'owner_claimed_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      }

      return ownerId == deviceId;
    });
  } catch (_) {
    final snap = await metaRef.get();
    final data = snap.data();
    final ownerId = (data?[_autoArchiveOwnerField] ?? '').toString().trim();
    return ownerId == deviceId;
  }
}

/// Auto-archive old sales into archive_bin on a schedule.
/// - Uses month boundary at 4 AM local time to pick old documents.
/// - Skips deferred sales entirely.
Future<void> runAutoArchiveIfNeeded({
  String? adminUid, // ممكن تسيبه null -> يكتب 'system'
  int batchSize = 300, // حجم الدُفعة
  Duration pause = const Duration(milliseconds: 120),
}) async {
  final db = FirebaseFirestore.instance;
  final metaRef = db
      .collection(_autoArchiveMetaCollection)
      .doc(_autoArchiveMetaDocId);
  final localPrefs = await SharedPreferences.getInstance();
  final deviceId = await getOrCreateAutoArchiveDeviceId(prefs: localPrefs);

  final now = DateTime.now();
  final effectiveMonth = _effectiveOperationalMonth(now);
  final monthStartUtc = monthRangeUtc(effectiveMonth).startUtc;

  // Fast pre-checks (no writes).
  final metaSnap = await metaRef.get();
  final metaData = metaSnap.data();
  final ownerId = (metaData?[_autoArchiveOwnerField] ?? '').toString().trim();
  if (ownerId.isNotEmpty && ownerId != deviceId) {
    return;
  }
  final lastRun = _asDate(metaData?['last_run']);
  if (lastRun != null && !lastRun.toUtc().isBefore(monthStartUtc)) {
    return;
  }

  final hasOld = await _hasAnyOldSales(monthStartUtc);
  if (!hasOld) {
    return;
  }

  // Lock to avoid multi-device auto-archive.
  final lockOk = await db.runTransaction((tx) async {
    final snap = await tx.get(metaRef);
    final data = snap.data();
    final txOwner = (data?[_autoArchiveOwnerField] ?? '').toString().trim();
    if (txOwner.isNotEmpty && txOwner != deviceId) {
      return false;
    }

    final txLastRun = _asDate(data?['last_run']);
    if (txLastRun != null && !txLastRun.toUtc().isBefore(monthStartUtc)) {
      return false;
    }

    final running = data?['running'] == true;
    final until = data?['running_until'];
    if (running && until is Timestamp && until.toDate().isAfter(now)) {
      return false;
    }

    tx.set(metaRef, {
      'running': true,
      'running_until': Timestamp.fromDate(now.add(const Duration(minutes: 20))),
      if (txOwner.isEmpty) _autoArchiveOwnerField: deviceId,
      if (txOwner.isEmpty) 'owner_claimed_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  });
  if (!lockOk) return;

  bool didRun = false;
  int moved = 0;
  final archiverId = (adminUid?.isNotEmpty ?? false) ? adminUid! : 'system';
  try {
    moved = await _archiveOldSales(
      cutoffUtc: monthStartUtc,
      batchSize: batchSize,
      pause: pause,
      archivedBy: archiverId,
    );
    didRun = true;

    // Generate archive_months for previous month once.
    final prevMonth = DateTime(
      effectiveMonth.year,
      effectiveMonth.month - 1,
      1,
    );
    await syncMonthlyArchiveForMonth(
      firestore: db,
      month: prevMonth,
      force: true,
    );
  } finally {
    try {
      await metaRef.set({
        'running': false,
        'running_until': FieldValue.serverTimestamp(),
        _autoArchiveOwnerField: deviceId,
        if (didRun) 'last_run': FieldValue.serverTimestamp(),
        if (didRun) 'by': archiverId,
        if (didRun) 'moved': moved,
        if (didRun)
          'cutoffMonth': DateTime(
            effectiveMonth.year,
            effectiveMonth.month,
            1,
            4,
          ).toIso8601String(),
        if (didRun) 'cutoffUtc': monthStartUtc.toIso8601String(),
        if (didRun) 'mode': 'monthly',
      }, SetOptions(merge: true));
    } catch (_) {
      // لا شيء
    }
  }
}

/// Manual trigger: archive old sales immediately (ignores lastRun).
Future<int> runAutoArchiveNow({
  String? adminUid,
  int batchSize = 300,
  Duration pause = const Duration(milliseconds: 120),
}) async {
  final db = FirebaseFirestore.instance;
  final metaRef = db
      .collection(_autoArchiveMetaCollection)
      .doc(_autoArchiveMetaDocId);
  final localPrefs = await SharedPreferences.getInstance();
  final deviceId = await getOrCreateAutoArchiveDeviceId(prefs: localPrefs);

  final nowLocal = DateTime.now();
  final effectiveMonth = _effectiveOperationalMonth(nowLocal);
  final monthStartUtc = monthRangeUtc(effectiveMonth).startUtc;

  final archiverId = (adminUid?.isNotEmpty ?? false) ? adminUid! : 'system';
  final moved = await _archiveOldSales(
    cutoffUtc: monthStartUtc,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archiverId,
  );

  try {
    await metaRef.set({
      _autoArchiveOwnerField: deviceId,
      'last_run': FieldValue.serverTimestamp(),
      'by': archiverId,
      'moved': moved,
      'cutoffMonth': DateTime(
        effectiveMonth.year,
        effectiveMonth.month,
        1,
        4,
      ).toIso8601String(),
      'cutoffUtc': monthStartUtc.toIso8601String(),
      'mode': 'manual',
    }, SetOptions(merge: true));
  } catch (_) {
    // لا شيء
  }

  // Generate archive_months for previous month once.
  final prevMonth = DateTime(effectiveMonth.year, effectiveMonth.month - 1, 1);
  await syncMonthlyArchiveForMonth(
    firestore: db,
    month: prevMonth,
    force: true,
  );

  return moved;
}

DateTime _effectiveOperationalMonth(DateTime nowLocal) {
  final monthStartLocal = DateTime(nowLocal.year, nowLocal.month, 1, 4);
  return nowLocal.isBefore(monthStartLocal)
      ? DateTime(nowLocal.year, nowLocal.month - 1, 1)
      : DateTime(nowLocal.year, nowLocal.month, 1);
}

DateTime? _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    final raw = value.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  return null;
}

String _generateUuidV4() {
  final random = Random.secure();

  String hex(int length) {
    const chars = '0123456789abcdef';
    final b = StringBuffer();
    for (var i = 0; i < length; i++) {
      b.write(chars[random.nextInt(chars.length)]);
    }
    return b.toString();
  }

  final variant = const ['8', '9', 'a', 'b'][random.nextInt(4)];
  return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
}

/// Moves old sales into archive_bin, then deletes originals.
/// Ensure the created_at index exists if Firestore requests it.
Future<int> _archiveOldSales({
  required DateTime cutoffUtc,
  required int batchSize,
  required Duration pause,
  String? archivedBy,
}) async {
  final cutoffIso = cutoffUtc.toIso8601String();
  final cutoffMs = cutoffUtc.millisecondsSinceEpoch;
  final cutoffSec = (cutoffMs / 1000).floor();

  int moved = 0;
  moved += await _archiveByFieldCutoff(
    field: 'created_at',
    cutoffValue: cutoffUtc,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archivedBy,
  );
  moved += await _archiveByFieldCutoff(
    field: 'created_at',
    cutoffValue: cutoffIso,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archivedBy,
  );
  moved += await _archiveByFieldCutoff(
    field: 'created_at',
    cutoffValue: cutoffMs,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archivedBy,
  );
  moved += await _archiveByFieldCutoff(
    field: 'created_at',
    cutoffValue: cutoffSec,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archivedBy,
  );

  moved += await _archiveByFieldCutoff(
    field: 'original_created_at',
    cutoffValue: cutoffUtc,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archivedBy,
    skipIfCreatedAtPresent: true,
  );
  moved += await _archiveByFieldCutoff(
    field: 'original_created_at',
    cutoffValue: cutoffIso,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archivedBy,
    skipIfCreatedAtPresent: true,
  );
  moved += await _archiveByFieldCutoff(
    field: 'original_created_at',
    cutoffValue: cutoffMs,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archivedBy,
    skipIfCreatedAtPresent: true,
  );
  moved += await _archiveByFieldCutoff(
    field: 'original_created_at',
    cutoffValue: cutoffSec,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archivedBy,
    skipIfCreatedAtPresent: true,
  );

  developer.log('Auto-archiver moved: $moved docs.');
  return moved;
}

Future<int> _archiveByFieldCutoff({
  required String field,
  required dynamic cutoffValue,
  required int batchSize,
  required Duration pause,
  String? archivedBy,
  bool skipIfCreatedAtPresent = false,
}) async {
  final db = FirebaseFirestore.instance;
  int moved = 0;
  DocumentSnapshot<Map<String, dynamic>>? last;

  while (true) {
    // ⚠️ بدون where(is_deferred, ...) لتفادي طلب Composite Index
    final lowerBound = _lowerBoundFor(cutoffValue);
    Query<Map<String, dynamic>> q = db
        .collection('sales')
        .where(field, isGreaterThanOrEqualTo: lowerBound)
        .where(field, isLessThan: cutoffValue)
        .orderBy(field) // Asc
        .limit(batchSize);

    if (last != null) q = q.startAfterDocument(last);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await q.get();
    } on FirebaseException catch (e) {
      // لو ظهر failed-precondition (index) مع orderBy واحد نادر جدًا؛ اطبع وأوقف
      developer.log('Auto-archiver query failed: ${e.code} ${e.message}');
      break;
    }

    if (snap.docs.isEmpty) break;

    var wb = db.batch();
    int ops = 0;
    int batchMoved = 0;
    const int maxOps = 450;

    for (final d in snap.docs) {
      final data = d.data();

      if (skipIfCreatedAtPresent && data['created_at'] != null) {
        final rawCreated = data['created_at'];
        final isSupported =
            rawCreated is Timestamp ||
            rawCreated is DateTime ||
            rawCreated is num ||
            rawCreated is String;
        if (isSupported) {
          continue;
        }
      }

      // تخطّي الأجل بالكامل
      final isDef = (data['is_deferred'] ?? false) == true;
      final isCredit = (data['is_credit'] ?? false) == true;
      if (isDef || isCredit) continue;

      final archiveMonthRef = _archiveMonthRefForSale(
        db,
        data,
        fallbackId: d.id,
      );
      final opsNeeded = archiveMonthRef == null ? 2 : 3;
      if (ops + opsNeeded > maxOps) {
        await wb.commit();
        wb = db.batch();
        ops = 0;
      }

      final archiveRef = db.collection(archiveBinCollection).doc();
      final archiveData = buildArchiveEntry(
        srcRef: d.reference,
        kind: 'sale',
        data: data,
        reason: 'auto_archive_old_sales',
        archivedBy: archivedBy,
      );
      wb.set(archiveRef, archiveData);
      if (archiveMonthRef != null) {
        wb.set(archiveMonthRef, data, SetOptions(merge: true));
      }
      wb.delete(d.reference);
      ops += 2;
      if (archiveMonthRef != null) ops += 1;
      batchMoved += 1;
    }

    if (ops > 0) {
      await wb.commit();
      moved += batchMoved;
    }

    last = snap.docs.last;
    await Future.delayed(pause);
  }

  return moved;
}

Future<bool> _hasAnyOldSales(DateTime cutoffUtc) async {
  final db = FirebaseFirestore.instance;
  final cutoffIso = cutoffUtc.toIso8601String();
  final cutoffMs = cutoffUtc.millisecondsSinceEpoch;
  final cutoffSec = (cutoffMs / 1000).floor();

  Future<bool> exists(Query<Map<String, dynamic>> q) async {
    try {
      final snap = await q.limit(1).get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  final queries = <Query<Map<String, dynamic>>>[
    db
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: _lowerBoundFor(cutoffUtc))
        .where('created_at', isLessThan: cutoffUtc)
        .orderBy('created_at'),
    db
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: _lowerBoundFor(cutoffIso))
        .where('created_at', isLessThan: cutoffIso)
        .orderBy('created_at'),
    db
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: _lowerBoundFor(cutoffMs))
        .where('created_at', isLessThan: cutoffMs)
        .orderBy('created_at'),
    db
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: _lowerBoundFor(cutoffSec))
        .where('created_at', isLessThan: cutoffSec)
        .orderBy('created_at'),
    db
        .collection('sales')
        .where(
          'original_created_at',
          isGreaterThanOrEqualTo: _lowerBoundFor(cutoffUtc),
        )
        .where('original_created_at', isLessThan: cutoffUtc)
        .orderBy('original_created_at'),
    db
        .collection('sales')
        .where(
          'original_created_at',
          isGreaterThanOrEqualTo: _lowerBoundFor(cutoffIso),
        )
        .where('original_created_at', isLessThan: cutoffIso)
        .orderBy('original_created_at'),
    db
        .collection('sales')
        .where(
          'original_created_at',
          isGreaterThanOrEqualTo: _lowerBoundFor(cutoffMs),
        )
        .where('original_created_at', isLessThan: cutoffMs)
        .orderBy('original_created_at'),
    db
        .collection('sales')
        .where(
          'original_created_at',
          isGreaterThanOrEqualTo: _lowerBoundFor(cutoffSec),
        )
        .where('original_created_at', isLessThan: cutoffSec)
        .orderBy('original_created_at'),
  ];

  for (final q in queries) {
    if (await exists(q)) return true;
  }
  return false;
}

dynamic _lowerBoundFor(dynamic cutoffValue) {
  if (cutoffValue is DateTime) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  if (cutoffValue is Timestamp) {
    return Timestamp.fromMillisecondsSinceEpoch(0);
  }
  if (cutoffValue is String) {
    return '';
  }
  if (cutoffValue is num) {
    return 0;
  }
  return null;
}

DocumentReference<Map<String, dynamic>>? _archiveMonthRefForSale(
  FirebaseFirestore db,
  Map<String, dynamic> data, {
  required String fallbackId,
}) {
  final raw = data['original_created_at'] ?? data['created_at'];
  final dt = _parseDateSafe(raw);
  if (dt == null) return null;
  final local = dt.toLocal();
  final shifted = local.subtract(const Duration(hours: 4));
  final year = shifted.year;
  final monthKey = shifted.month.toString().padLeft(2, '0');
  final id = (data['id'] ?? data['sale_id'] ?? '').toString().trim();
  final docId = id.isNotEmpty ? id : fallbackId;
  return db.collection('archive').doc('$year').collection(monthKey).doc(docId);
}

DateTime? _parseDateSafe(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    final raw = value.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
