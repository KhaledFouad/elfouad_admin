import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/time.dart';
import 'package:elfouad_admin/data/data_source/firestore_sales_ds.dart';
import 'package:elfouad_admin/data/repo/sales_repo_impl.dart';
import 'package:elfouad_admin/domain/use_cases/build_breakdowns.dart';
import 'package:elfouad_admin/domain/use_cases/get_sales_in_range.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final _dsProvider = Provider<FirestoreSalesDs>(
  (ref) => FirestoreSalesDs(FirebaseFirestore.instance),
);
final _repoProvider = Provider<SalesRepoImpl>(
  (ref) => SalesRepoImpl(ref.read(_dsProvider)),
);
final getSalesInRangeProvider = Provider<GetSalesInRange>(
  (ref) => GetSalesInRange(ref.read(_repoProvider)),
);
final buildBreakdownsProvider = Provider<BuildBreakdowns>(
  (ref) => BuildBreakdowns(),
);

final monthRangeProvider = StateProvider<DateTimeRangeUtc>((ref) {
  final r = OpTime.monthOperationalRangeUtc(DateTime.now());
  return DateTimeRangeUtc(r.$1, r.$2);
});

final salesBreakdownsProviderMonth = FutureProvider<Breakdowns>((ref) async {
  final r = ref.watch(monthRangeProvider);
  final getSales = ref.read(getSalesInRangeProvider);
  final builder = ref.read(buildBreakdownsProvider);
  final sales = await getSales(r.startUtc, r.endUtc);
  return builder(sales);
});

class DayPoint {
  final DateTime day;
  final double value;
  DayPoint(this.day, this.value);
}

final salesTrendMonthProvider = FutureProvider<List<DayPoint>>((ref) async {
  final r = ref.watch(monthRangeProvider);
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

final profitTrendMonthProvider = FutureProvider<List<DayPoint>>((ref) async {
  final r = ref.watch(monthRangeProvider);
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
