import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'date_range_controller.dart';

// كل عمليات الأجل غير المدفوعة — بدون فلتر تاريخ
final unpaidDeferredStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      return FirebaseFirestore.instance
          .collection('sales')
          .where('is_deferred', isEqualTo: true)
          .where('paid', isEqualTo: false)
          .snapshots(includeMetadataChanges: true);
    });

final salesQueryProvider = Provider<Query<Map<String, dynamic>>>((ref) {
  final r = ref.watch(dateRangeProvider) ?? DateRangeController.today();
  const pageSize = 500; // جرّب 100–300 حسب يومك
  return FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isGreaterThanOrEqualTo: r.start.toUtc())
      .where('created_at', isLessThan: r.end.toUtc())
      .orderBy('created_at', descending: true)
      .limit(pageSize);
});

/// Live stream of snapshots for the page.
final salesStreamProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>(
  (ref) {
    return ref
        .watch(salesQueryProvider)
        .snapshots(includeMetadataChanges: true); // cache → server
  },
);

// عدّاد عمليات الأجل غير المدفوعة (بدون orderBy وبدون فهرس مركّب)
final deferredCountStreamProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('sales')
      .where('is_deferred', isEqualTo: true)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snap) =>
            snap.docs.where((d) => (d.data()['paid'] ?? false) == false).length,
      );
});
