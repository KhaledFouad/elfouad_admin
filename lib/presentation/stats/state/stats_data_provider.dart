import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/op_day.dart';
import 'sales_raw_provider.dart';

class Kpis {
  final double sales, cost, profit, grams;
  final int cups;
  const Kpis({
    required this.sales,
    required this.cost,
    required this.profit,
    required this.cups,
    required this.grams,
  });
}

class GroupRow {
  final String key;
  final double sales, cost, profit, grams;
  final int cups;
  const GroupRow({
    required this.key,
    this.sales = 0,
    this.cost = 0,
    this.profit = 0,
    this.grams = 0,
    this.cups = 0,
  });

  GroupRow add({
    double s = 0,
    double c = 0,
    double p = 0,
    double g = 0,
    int cu = 0,
  }) => GroupRow(
    key: key,
    sales: sales + s,
    cost: cost + c,
    profit: profit + p,
    grams: grams + g,
    cups: cups + cu,
  );
}

final kpisProvider = Provider<Kpis>((ref) {
  final data = ref.watch(salesRawProvider).value ?? const [];
  double sales = 0, cost = 0, grams = 0;
  int cups = 0;
  for (final m in data) {
    final type = '${m['type'] ?? ''}';
    final price = (m['total_price'] is num)
        ? (m['total_price'] as num).toDouble()
        : double.tryParse('${m['total_price'] ?? 0}') ?? 0;
    final tcost = (m['total_cost'] is num)
        ? (m['total_cost'] as num).toDouble()
        : double.tryParse('${m['total_cost'] ?? 0}') ?? 0;
    sales += price;
    cost += tcost;
    if (type == 'drink') {
      final q = (m['quantity'] is num)
          ? (m['quantity'] as num).toDouble()
          : double.tryParse('${m['quantity'] ?? 1}') ?? 1;
      cups += (q > 0 ? q.round() : 1);
    } else if (type == 'single' || type == 'ready_blend') {
      grams += (m['grams'] is num)
          ? (m['grams'] as num).toDouble()
          : double.tryParse('${m['grams'] ?? 0}') ?? 0;
    } else if (type == 'custom_blend') {
      grams += (m['total_grams'] is num)
          ? (m['total_grams'] as num).toDouble()
          : double.tryParse('${m['total_grams'] ?? 0}') ?? 0;
    }
  }
  return Kpis(
    sales: sales,
    cost: cost,
    profit: sales - cost,
    cups: cups,
    grams: grams,
  );
});

/// مشروبات حسب النوع (كل الأنواع المخزنة بالعربي)
final drinksByTypeProvider = Provider<List<GroupRow>>((ref) {
  final data = ref.watch(salesRawProvider).value ?? const [];
  final map = <String, GroupRow>{};
  for (final m in data) {
    if ('${m['type'] ?? ''}' != 'drink') continue;
    final key = ('${m['drink_type'] ?? ''}').trim().isNotEmpty
        ? '${m['drink_type']}'
        : ('${m['drink_name'] ?? m['name'] ?? 'غير مُصنّف'}');
    final price = (m['total_price'] as num?)?.toDouble() ?? 0;
    final cost = (m['total_cost'] as num?)?.toDouble() ?? 0;
    final qRaw = (m['quantity'] as num?)?.toDouble() ?? 1;
    final cups = (qRaw > 0 ? qRaw.round() : 1);
    final prev = map[key] ?? GroupRow(key: key);
    map[key] = prev.add(s: price, c: cost, p: price - cost, cu: cups);
  }
  final list = map.values.toList();
  list.sort((a, b) => b.sales.compareTo(a.sales));
  return list;
});

/// البن حسب العائلة/المنشأ (كل القيم بالعربي من الداتابيز)
final beansByFamilyProvider = Provider<List<GroupRow>>((ref) {
  final data = ref.watch(salesRawProvider).value ?? const [];
  final map = <String, GroupRow>{};
  for (final m in data) {
    final type = '${m['type'] ?? ''}';
    if (type == 'drink') continue;
    final isReady = type == 'ready_blend';
    final isSingle = type == 'single';
    final isCustom = type == 'custom_blend';
    String key = isReady
        ? ('${m['blend_family'] ?? 'غير مُصنّف'}')
        : isSingle
        ? ('${m['single_origin'] ?? m['name'] ?? 'غير مُصنّف'}')
        : ('${m['blend_family'] ?? 'مخصص'}');
    final price = (m['total_price'] as num?)?.toDouble() ?? 0;
    final cost = (m['total_cost'] as num?)?.toDouble() ?? 0;
    final grams = isCustom
        ? ((m['total_grams'] as num?)?.toDouble() ?? 0)
        : ((m['grams'] as num?)?.toDouble() ?? 0);
    final prev = map[key] ?? GroupRow(key: key);
    map[key] = prev.add(s: price, c: cost, p: price - cost, g: grams);
  }
  final list = map.values.toList();
  list.sort((a, b) => b.grams.compareTo(a.grams));
  return list;
});

/// Top 5
final top5DrinksByCupsProvider = Provider<List<GroupRow>>((ref) {
  final list = ref.watch(drinksByTypeProvider);
  final sorted = [...list]..sort((a, b) => b.cups.compareTo(a.cups));
  return sorted.take(5).toList();
});

final top5DrinksByProfitProvider = Provider<List<GroupRow>>((ref) {
  final list = ref.watch(drinksByTypeProvider);
  final sorted = [...list]..sort((a, b) => b.profit.compareTo(a.profit));
  return sorted.take(5).toList();
});

final top5BeansByGramsProvider = Provider<List<GroupRow>>((ref) {
  final list = ref.watch(beansByFamilyProvider);
  final sorted = [...list]..sort((a, b) => b.grams.compareTo(a.grams));
  return sorted.take(5).toList();
});

final top5BeansByProfitProvider = Provider<List<GroupRow>>((ref) {
  final list = ref.watch(beansByFamilyProvider);
  final sorted = [...list]..sort((a, b) => b.profit.compareTo(a.profit));
  return sorted.take(5).toList();
});

/// ترندات 3 خطوط
class DayVal {
  final DateTime day;
  final double v;
  DayVal(this.day, this.v);
}

final trends3Provider =
    Provider<
      ({
        List<DayVal> totalSales,
        List<DayVal> totalProfit,
        List<DayVal> drinksSales,
        List<DayVal> beansGrams,
      })
    >((ref) {
      final data = ref.watch(salesRawProvider).value ?? const [];
      final Map<DateTime, double> salesM = {},
          profitM = {},
          drinksM = {},
          gramsM = {};
      for (final m in data) {
        final ts =
            (m['created_at'] as Timestamp?)?.toDate().toUtc() ??
            DateTime.tryParse('${m['created_at'] ?? ''}')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final k = opDayKeyUtc(ts);
        final type = '${m['type'] ?? ''}';
        final price = (m['total_price'] as num?)?.toDouble() ?? 0;
        final cost = (m['total_cost'] as num?)?.toDouble() ?? 0;
        salesM[k] = (salesM[k] ?? 0) + price;
        profitM[k] = (profitM[k] ?? 0) + (price - cost);
        if (type == 'drink') {
          drinksM[k] = (drinksM[k] ?? 0) + price;
        } else if (type == 'single' || type == 'ready_blend') {
          gramsM[k] =
              (gramsM[k] ?? 0) + ((m['grams'] as num?)?.toDouble() ?? 0);
        } else if (type == 'custom_blend') {
          gramsM[k] =
              (gramsM[k] ?? 0) + ((m['total_grams'] as num?)?.toDouble() ?? 0);
        }
      }
      List<DayVal> conv(Map<DateTime, double> mp) {
        final ks = mp.keys.toList()..sort();
        return ks.map((d) => DayVal(d, mp[d] ?? 0)).toList();
      }

      return (
        totalSales: conv(salesM),
        totalProfit: conv(profitM),
        drinksSales: conv(drinksM),
        beansGrams: conv(gramsM),
      );
    });
