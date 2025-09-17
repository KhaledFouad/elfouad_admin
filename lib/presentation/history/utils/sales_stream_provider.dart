import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'date_range_controller.dart';

final salesQueryProvider = Provider<Query<Map<String, dynamic>>>((ref) {
  final r = ref.watch(dateRangeProvider) ?? DateRangeController.today();
  const pageSize = 200; // جرّب 100–300 حسب يومك
  return FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isGreaterThanOrEqualTo: r.start.toUtc())
      .where('created_at', isLessThan: r.end.toUtc())
      .orderBy('created_at', descending: true)
      .limit(pageSize);
});

/// Live stream of snapshots for the page.
// sales_stream_provider.dart
final salesStreamProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>(
  (ref) {
    return ref
        .watch(salesQueryProvider)
        .snapshots(includeMetadataChanges: true); // cache → server
  },
);
