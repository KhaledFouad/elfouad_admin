// lib/services/auto_archiver.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/stats/utils/op_day.dart'
    show monthRangeUtc;
import 'package:elfouad_admin/services/archive/archive_service.dart';

/// Auto-archive old sales into archive_bin on a schedule.
/// - Uses month boundary at 4 AM local time to pick old documents.
/// - Skips deferred unpaid sales.
Future<void> runAutoArchiveIfNeeded({
  String? adminUid, // ممكن تسيبه null -> يكتب 'system'
  int batchSize = 300, // حجم الدُفعة
  Duration pause = const Duration(milliseconds: 120),
}) async {
  final db = FirebaseFirestore.instance;
  final metaRef = db.collection('meta').doc('archiver');

  // اقرأ آخر مرة اشتغل فيها
  DateTime? lastRun;
  try {
    final meta = await metaRef.get();
    final v = meta.data()?['lastRun'];
    if (v is Timestamp) lastRun = v.toDate();
  } catch (_) {
    // تجاهل القراءة الفاشلة
  }

  final nowLocal = DateTime.now();
  final monthStartLocal = DateTime(nowLocal.year, nowLocal.month, 1, 4);
  final effectiveMonth =
      nowLocal.isBefore(monthStartLocal)
          ? DateTime(nowLocal.year, nowLocal.month - 1, 1)
          : DateTime(nowLocal.year, nowLocal.month, 1);
  final monthStartUtc = monthRangeUtc(effectiveMonth).startUtc;
  final lastRunUtc = lastRun?.toUtc();
  final needRun = lastRunUtc == null || lastRunUtc.isBefore(monthStartUtc);
  if (!needRun) {
    final hasOld = await _hasAnyOldSales(monthStartUtc);
    if (!hasOld) return;
  }

  // نفذ الأرشفة
  final archiverId = (adminUid?.isNotEmpty ?? false) ? adminUid! : 'system';
  final monthCutoff = monthStartUtc;
  final moved = await _archiveOldSales(
    cutoffUtc: monthCutoff,
    batchSize: batchSize,
    pause: pause,
    archivedBy: archiverId,
  );

  // سجّل آخر تشغيل
  try {
    await metaRef.set({
      'lastRun': FieldValue.serverTimestamp(),
      'by': archiverId,
      'moved': moved,
      'cutoffMonth': DateTime(
        effectiveMonth.year,
        effectiveMonth.month,
        1,
        4,
      ).toIso8601String(),
      'cutoffUtc': monthCutoff.toIso8601String(),
      'mode': 'monthly',
    }, SetOptions(merge: true));
  } catch (_) {
    // لا شيء
  }
}

/// Manual trigger: archive old sales immediately (ignores lastRun).
Future<int> runAutoArchiveNow({
  String? adminUid,
  int batchSize = 300,
  Duration pause = const Duration(milliseconds: 120),
}) async {
  final db = FirebaseFirestore.instance;
  final metaRef = db.collection('meta').doc('archiver');

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
      'lastRun': FieldValue.serverTimestamp(),
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

      // تخطّي الأجل غير المدفوع
      final isDef = (data['is_deferred'] ?? false) == true;
      final paid = (data['paid'] ?? false) == true;
      if (isDef && !paid) continue;

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
