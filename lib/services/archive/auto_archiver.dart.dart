// lib/services/auto_archiver.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

/// يشغّل الأرشفة تلقائيًا لو آخر تشغيل كان من ≥ everyNDays أيام.
/// - ينقل المستندات الأقدم من [daysThreshold] يومًا إلى: archive/YYYY/MM/{id}
/// - يتجاوز الأجل غير المدفوع (is_deferred==true && paid!=true)
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
  final moved = await _archiveOldSales(
    daysThreshold: daysThreshold,
    batchSize: batchSize,
    pause: pause,
  );

  // سجّل آخر تشغيل
  try {
    await metaRef.set({
      'lastRun': FieldValue.serverTimestamp(),
      'by': (adminUid?.isNotEmpty ?? false) ? adminUid : 'system',
      'moved': moved,
      'daysThreshold': daysThreshold,
    }, SetOptions(merge: true));
  } catch (_) {
    // لا شيء
  }
}

/// ينقل دفعات من sales → archive/YYYY/MM/{id} ثم يحذف الأصل.
/// لا يحتاج Composite Index (نستعلم created_at فقط ونفلتر الأجل غير المدفوع في الكلاينت).
Future<int> _archiveOldSales({
  required int daysThreshold,
  required int batchSize,
  required Duration pause,
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

    for (final d in snap.docs) {
      final data = d.data();

      // تخطّي الأجل غير المدفوع
      final isDef = (data['is_deferred'] ?? false) == true;
      final paid = (data['paid'] ?? false) == true;
      if (isDef && !paid) continue;

      // استخرج التاريخ
      DateTime created;
      final v = data['created_at'];
      if (v is Timestamp) {
        created = v.toDate();
      } else if (v is DateTime) {
        created = v;
      } else {
        created = DateTime.fromMillisecondsSinceEpoch(0);
      }
      final y = created.toUtc().year.toString();
      final m = created.toUtc().month.toString().padLeft(2, '0');

      // المسار: archive/YYYY/MM/{id}
      final dest = db.collection('archive').doc(y).collection(m).doc(d.id);

      wb.set(dest, data, SetOptions(merge: false)); // copy
      wb.delete(d.reference); // delete original
      ops += 2;
    }

    if (ops > 0) {
      await wb.commit();
      moved += snap.docs.length;
    }

    last = snap.docs.last;
    await Future.delayed(pause);
  }

  developer.log('Auto-archiver moved: $moved docs.');
  return moved;
}
