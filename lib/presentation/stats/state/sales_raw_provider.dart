import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stats_period.dart';

/// بنرجّع List<Map> مباشرة من Firestore على المدى المختار
final salesRawProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final r = ref.watch(statsRangeProvider);
  final snap = await FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isGreaterThanOrEqualTo: r.startUtc)
      .where('created_at', isLessThan: r.endUtc)
      .orderBy('created_at')
      .get();
  return snap.docs.map((d) => d.data()).toList();
});
