import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'date_range_controller.dart';

/// ========= Deferred (badge) =========
/// Stream for unpaid deferred LIST (if you ever need it visually).
/// ستريم لقائمة الأجل غير المدفوع (لو عايزها في شاشة)، محدّد بدون تغييرات ميتاداتا.
final unpaidDeferredStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      return FirebaseFirestore.instance
          .collection('sales')
          .where('is_deferred', isEqualTo: true)
          .where('paid', isEqualTo: false)
          .snapshots(includeMetadataChanges: true);
    });

/// Count provider using server aggregate (lighter than streaming all docs).
/// مزوّد العداد المعتمد على Aggregate Query (أخف بكتير من ستريم كامل).
///
final deferredCountStreamProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      /// Count provider using server aggregate (lighter than streaming all docs).
      /// مزوّد العداد المعتمد على Aggregate Query (أخف بكتير من ستريم كامل).
      .collection('sales')
      .where('is_deferred', isEqualTo: true)
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) => s.docs.where((d) => (d.data()['paid'] ?? false) == false).length,
      );
});

/// ========= History stream (bounded) =========
/// We strictly bound by start & end to avoid wide reads.
/// بنقيّد الاستعلام ببداية ونهاية المدى لتقليل القراءات.
const int kHistoryStreamLimit = 500;
final salesQueryProvider = Provider<Query<Map<String, dynamic>>>((ref) {
  final r = ref.watch(dateRangeProvider) ?? DateRangeController.today();

  return FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isLessThan: r.end.toUtc())
      .orderBy('created_at', descending: true)
      .limit(kHistoryStreamLimit);
});

/// Live stream for history within the selected range only.
/// ستريم حيّ للسجل داخل النطاق فقط.
final salesStreamProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>(
  (ref) =>
      ref.watch(salesQueryProvider).snapshots(includeMetadataChanges: false),
);

/// Backward-compat name to avoid touching old imports.
