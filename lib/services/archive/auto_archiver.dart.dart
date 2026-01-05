// lib/services/auto_archiver.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/services/archive/archive_service.dart';

/// Auto-archive old sales into archive_bin on a schedule.
/// - Uses daysThreshold to pick old documents.
/// - Skips deferred unpaid sales.
Future<void> runAutoArchiveIfNeeded({
  String? adminUid, // ممكن تسيبه null -> يكتب 'system'
  int everyNDays = 5, // كل كام يوم يشتغل تلقائي
  int daysThreshold = 40, // الأقدم من كام يوم يتأرشف
  int batchSize = 200, // حجم الدُفعة
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

  final nowUtc = DateTime.now().toUtc();
  final needRun =
      lastRun == null || nowUtc.difference(lastRun).inDays >= everyNDays;
  if (!needRun) return;

  // نفذ الأرشفة
  final archiverId =
      (adminUid?.isNotEmpty ?? false) ? adminUid! : 'system';
  final moved = await _archiveOldSales(
    daysThreshold: daysThreshold,
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
      'daysThreshold': daysThreshold,
    }, SetOptions(merge: true));
  } catch (_) {
    // لا شيء
  }
}

/// Moves old sales into archive_bin, then deletes originals.
/// Ensure the created_at index exists if Firestore requests it.
Future<int> _archiveOldSales({
  required int daysThreshold,
  required int batchSize,
  required Duration pause,
  String? archivedBy,
}) async {
  final db = FirebaseFirestore.instance;
  final cutoff = DateTime.now().toUtc().subtract(Duration(days: daysThreshold));

  int moved = 0;
  DocumentSnapshot<Map<String, dynamic>>? last;

  while (true) {
    // ⚠️ بدون where(is_deferred, ...) لتفادي طلب Composite Index
    Query<Map<String, dynamic>> q = db
        .collection('sales')
        .where('created_at', isLessThan: cutoff)
        .orderBy('created_at') // Asc
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

    final wb = db.batch();
    int ops = 0;
    int batchMoved = 0;

    for (final d in snap.docs) {
      final data = d.data();

      // تخطّي الأجل غير المدفوع
      final isDef = (data['is_deferred'] ?? false) == true;
      final paid = (data['paid'] ?? false) == true;
      if (isDef && !paid) continue;
      final archiveRef = db.collection(archiveBinCollection).doc();
      final archiveData = buildArchiveEntry(
        srcRef: d.reference,
        kind: 'sale',
        data: data,
        reason: 'auto_archive_old_sales',
        archivedBy: archivedBy,
      );
      wb.set(archiveRef, archiveData);
      wb.delete(d.reference);
      ops += 2;
      batchMoved += 1;
    }

    if (ops > 0) {
      await wb.commit();
      moved += batchMoved;
    }

    last = snap.docs.last;
    await Future.delayed(pause);
  }

  developer.log('Auto-archiver moved: $moved docs.');
  return moved;
}
