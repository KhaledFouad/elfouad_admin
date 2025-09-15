import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/utils/time.dart';
import '../../../domain/use_cases/get_sales_in_range.dart';
import '../../../domain/use_cases/build_breakdowns.dart';
import '../../../data/repo/sales_repo_impl.dart';
import '../../../data/data_source/firestore_sales_ds.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// DI for UseCases (if used elsewhere)
final getSalesInRangeProvider = Provider<GetSalesInRange>((ref) {
  final ds = FirestoreSalesDs(FirebaseFirestore.instance);
  final repo = SalesRepoImpl(ds);
  return GetSalesInRange(repo);
});

final buildBreakdownsProvider = Provider<BuildBreakdowns>(
  (ref) => BuildBreakdowns(),
);

// Date range provider (UTC)
final dateRangeProvider = StateProvider<DateTimeRangeUtc>((ref) {
  final r = OpTime.todayOperationalRangeUtc();
  return DateTimeRangeUtc(r.$1, r.$2);
});

// Breakdowns provider for convenience
final salesBreakdownsProvider = FutureProvider<Breakdowns>((ref) async {
  final r = ref.watch(dateRangeProvider);
  final getSales = ref.read(getSalesInRangeProvider);
  final builder = ref.read(buildBreakdownsProvider);
  final sales = await getSales(r.startUtc, r.endUtc);
  return builder(sales);
});

// DayPoint model for trends
class DayPoint {
  final DateTime day; // UTC 4AM key
  final double value;
  DayPoint(this.day, this.value);
}

// Sales trend (sum of totalPrice per operational day)
final salesTrendProvider = FutureProvider<List<DayPoint>>((ref) async {
  final r = ref.watch(dateRangeProvider);
  final getSales = ref.read(getSalesInRangeProvider);
  final list = await getSales(r.startUtc, r.endUtc);
  final map = <DateTime, double>{};
  for (final s in list) {
    final k = OpTime.opDayKeyUtc(s.createdAt);
    map[k] = (map[k] ?? 0) + s.totalPrice;
  }
  final days = map.keys.toList()..sort();
  return days.map((d) => DayPoint(d, map[d] ?? 0)).toList();
});

// Profit trend (sum of (price - cost) per operational day)
final profitTrendProvider = FutureProvider<List<DayPoint>>((ref) async {
  final r = ref.watch(dateRangeProvider);
  final getSales = ref.read(getSalesInRangeProvider);
  final list = await getSales(r.startUtc, r.endUtc);
  final map = <DateTime, double>{};
  for (final s in list) {
    final k = OpTime.opDayKeyUtc(s.createdAt);
    final profit = s.totalPrice - s.totalCost;
    map[k] = (map[k] ?? 0) + profit;
  }
  final days = map.keys.toList()..sort();
  return days.map((d) => DayPoint(d, map[d] ?? 0)).toList();
});
