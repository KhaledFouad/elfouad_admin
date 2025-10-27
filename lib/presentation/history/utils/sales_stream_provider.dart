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
          .orderBy('created_at', descending: true)
          .limit(200) // safety cap
          .snapshots(includeMetadataChanges: false);
    });

/// Count provider using server aggregate (lighter than streaming all docs).
/// مزوّد العداد المعتمد على Aggregate Query (أخف بكتير من ستريم كامل).
final deferredUnpaidCountProvider = StreamProvider<int>((ref) {
  final q = FirebaseFirestore.instance
      .collection('sales')
      .where('is_deferred', isEqualTo: true)
      .where('paid', isEqualTo: false);

  // poll every 20s; avoids a permanent stream of all docs
  return Stream.periodic(const Duration(seconds: 20)).asyncMap((_) async {
    final agg = await q.count().get(source: AggregateSource.server);
    return agg.count ?? 0;
  });
});

/// ========= History stream (bounded) =========
/// We strictly bound by start & end to avoid wide reads.
/// بنقيّد الاستعلام ببداية ونهاية المدى لتقليل القراءات.
const int kHistoryStreamLimit = 500;

final salesQueryProvider = Provider<Query<Map<String, dynamic>>>((ref) {
  final range = ref.watch(dateRangeProvider) ?? DateRangeController.today();
  final startUtc = range.start.toUtc();
  final endUtc = range.end.toUtc();

  return FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isGreaterThanOrEqualTo: startUtc)
      .where('created_at', isLessThan: endUtc)
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
final deferredCountStreamProvider = deferredUnpaidCountProvider;
