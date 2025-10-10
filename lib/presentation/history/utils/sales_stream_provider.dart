import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'date_range_controller.dart';

/// كل عمليات الأجل غير المدفوعة — (لشِبّ badge فقط)
final unpaidDeferredStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      return FirebaseFirestore.instance
          .collection('sales')
          .where('is_deferred', isEqualTo: true)
          .where('paid', isEqualTo: false)
          .snapshots(includeMetadataChanges: true);
    });

/// عدّاد الأجل (Badge)
final deferredCountStreamProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('sales')
      .where('is_deferred', isEqualTo: true)
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) => s.docs.where((d) => (d.data()['paid'] ?? false) == false).length,
      );
});

/// Query أساسي: لحد نهاية المدى فقط + limit كبير.
/// (الترحيل/الفلترة بتتم على مستوى الواجهة)
final salesQueryProvider = Provider<Query<Map<String, dynamic>>>((ref) {
  final r = ref.watch(dateRangeProvider) ?? DateRangeController.today();
  return FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isLessThan: r.end.toUtc())
      .orderBy('created_at', descending: true)
      .limit(500);
});

/// Stream حيّ للسجل
final salesStreamProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>(
  (ref) =>
      ref.watch(salesQueryProvider).snapshots(includeMetadataChanges: true),
);
