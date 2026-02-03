// lib/services/auto_archiver.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/stats/utils/op_day.dart'
    show monthRangeUtc;
import 'package:elfouad_admin/services/archive/archive_service.dart';

/// Auto-archive old sales into archive_bin on a schedule.
/// - Uses month boundary at 4 AM local time to pick old documents.
/// - Skips deferred sales entirely.
Future<void> runAutoArchiveIfNeeded({
  String? adminUid, // ممكن تسيبه null -> يكتب 'system'
  int batchSize = 300, // حجم الدُفعة
  Duration pause = const Duration(milliseconds: 120),
}) async {
  final db = FirebaseFirestore.instance;
  final metaRef = db.collection('meta').doc('auto_archive');

  // Lock to avoid multi-device auto-archive.
  DateTime? lastRun;
  final now = DateTime.now();
  final lockOk = await db.runTransaction((tx) async {
    final snap = await tx.get(metaRef);
    final data = snap.data();
    final running = data?['running'] == true;
    final until = data?['running_until'];
    if (running && until is Timestamp) {
      if (until.toDate().isAfter(now)) {
        return false;
      }
    }
    final v = data?['last_run'];
    if (v is Timestamp) lastRun = v.toDate();
    tx.set(metaRef, {
      'running': true,
      'running_until': Timestamp.fromDate(
        now.add(const Duration(minutes: 20)),
      ),
    }, SetOptions(merge: true));
    return true;
  });
  if (!lockOk) return;

  final nowLocal = now;
  final monthStartLocal = DateTime(nowLocal.year, nowLocal.month, 1, 4);
  final effectiveMonth =
      nowLocal.isBefore(monthStartLocal)
          ? DateTime(nowLocal.year, nowLocal.month - 1, 1)
          : DateTime(nowLocal.year, nowLocal.month, 1);
  final monthStartUtc = monthRangeUtc(effectiveMonth).startUtc;
  final lastRunUtc = lastRun?.toUtc();
  final needRun = lastRunUtc == null || lastRunUtc.isBefore(monthStartUtc);
  bool didRun = false;
  int moved = 0;
  final archiverId = (adminUid?.isNotEmpty ?? false) ? adminUid! : 'system';
  try {
    if (!needRun) {
      final hasOld = await _hasAnyOldSales(monthStartUtc);
      if (!hasOld) return;
    }

    // نفذ الأرشفة
    final monthCutoff = monthStartUtc;
    moved = await _archiveOldSales(
      cutoffUtc: monthCutoff,
      batchSize: batchSize,
      pause: pause,
      archivedBy: archiverId,
    );
    didRun = true;

    // Optional: update archive_months from archive_daily (no sales scan).
    final prevMonth = DateTime(
      effectiveMonth.year,
      effectiveMonth.month - 1,
      1,
    );
    await _updateArchiveMonthSummaryFromDaily(db, prevMonth);
  } finally {
    try {
      await metaRef.set({
        'running': false,
        'running_until': FieldValue.serverTimestamp(),
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
  final metaRef = db.collection('meta').doc('auto_archive');

  final nowLocal = DateTime.now();
  final monthStartLocal = DateTime(nowLocal.year, nowLocal.month, 1, 4);
  final effectiveMonth =
      nowLocal.isBefore(monthStartLocal)
          ? DateTime(nowLocal.year, nowLocal.month - 1, 1)
          : DateTime(nowLocal.year, nowLocal.month, 1);
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

  // Optional: update archive_months from archive_daily (no sales scan).
  final prevMonth = DateTime(
    effectiveMonth.year,
    effectiveMonth.month - 1,
    1,
  );
  await _updateArchiveMonthSummaryFromDaily(db, prevMonth);

  return moved;
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
        final isSupported = rawCreated is Timestamp ||
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

Future<void> _updateArchiveMonthSummaryFromDaily(
  FirebaseFirestore db,
  DateTime month,
) async {
  final year = month.year;
  final monthKey = month.month.toString().padLeft(2, '0');
  final dailyRef = db
      .collection('archive_daily')
      .doc('$year')
      .collection(monthKey);
  QuerySnapshot<Map<String, dynamic>> snap;
  try {
    snap = await dailyRef.get();
  } catch (_) {
    return;
  }
  if (snap.docs.isEmpty) return;

  double sales = 0, cost = 0, profit = 0, grams = 0, expenses = 0;
  int cups = 0, units = 0;

  double numVal(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }

  int intVal(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  for (final doc in snap.docs) {
    final data = doc.data();
    sales += numVal(data['sales']);
    cost += numVal(data['cost']);
    profit += numVal(data['profit']);
    grams += numVal(data['grams']);
    expenses += numVal(data['expenses']);
    cups += intVal(data['cups'] ?? data['drinks']);
    units += intVal(data['units'] ?? data['snacks']);
  }

  final monthId = '$year-$monthKey';
  await db.collection('archive_months').doc(monthId).set({
    'summary': {
      'sales': sales,
      'cost': cost,
      'profit': profit,
      'grams': grams,
      'drinks': cups,
      'snacks': units,
      'expenses': expenses,
    },
    'year': year,
    'monthNumber': month.month,
    'monthKey': monthId,
    'source': 'archive_daily',
    'updated_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
