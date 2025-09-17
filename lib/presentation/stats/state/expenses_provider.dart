import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stats_period.dart';

final expensesTotalProvider = FutureProvider<double>((ref) async {
  final r = ref.watch(statsRangeProvider);
  final q = await FirebaseFirestore.instance
      .collection('expenses')
      .where('created_at', isGreaterThanOrEqualTo: r.startUtc)
      .where('created_at', isLessThan: r.endUtc)
      .get();
  double s = 0;
  for (final d in q.docs) {
    final v = d.data()['amount'];
    s += (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;
  }
  return s;
});
