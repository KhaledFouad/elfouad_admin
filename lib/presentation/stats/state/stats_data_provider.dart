import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/op_day.dart';
import 'sales_raw_provider.dart';
import 'stats_period.dart';

/// ============ Models ============

class Kpis {
  final double sales, cost, profit, grams;
  final int cups, units;
  final double expenses;
  const Kpis({
    required this.sales,
    required this.cost,
    required this.profit,
    required this.cups,
    required this.grams,
    required this.expenses,
    required this.units,
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

  String get name => key;

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

class DayVal {
  final DateTime day;
  final double v;
  const DayVal(this.day, this.v);
}

class DayHighlight {
  final DateTime day;
  final double sales;
  final double profit;
  final int servings;
  final int orders;
  const DayHighlight({
    required this.day,
    required this.sales,
    required this.profit,
    required this.servings,
    required this.orders,
  });
}

class StatsHighlights {
  final DayHighlight? topSalesDay;
  final DayHighlight? topProfitDay;
  final DayHighlight? busiestDay;
  final double averageOrderValue;
  final double averageDailySales;
  final int totalOrders;
  final int activeDays;
  final int totalServings;
  const StatsHighlights({
    required this.topSalesDay,
    required this.topProfitDay,
    required this.busiestDay,
    required this.averageOrderValue,
    required this.averageDailySales,
    required this.totalOrders,
    required this.activeDays,
    required this.totalServings,
  });
}

class StatsOverview {
  final Kpis kpis;
  final List<GroupRow> drinks;
  final List<GroupRow> beans;
  final List<GroupRow> extras;
  final TrendsBundle trends;
  final StatsHighlights highlights;
  const StatsOverview({
    required this.kpis,
    required this.drinks,
    required this.beans,
    required this.extras,
    required this.trends,
    required this.highlights,
  });
}

/// ============ Helpers ============

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

DateTime _asUtc(dynamic v) {
  if (v is DateTime) return v.toUtc();
  try {
    // Firestore Timestamp (dynamic)
    // ignore: avoid_dynamic_calls
    if (v != null && v.toDate != null) {
      // ignore: avoid_dynamic_calls
      final dt = v.toDate();
      if (dt is DateTime) return dt.toUtc();
    }
  } catch (_) {}
  if (v is String) {
    return DateTime.tryParse(v)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

bool _inRangeUtc(DateTime ts, DateTime start, DateTime end) {
  final afterOrEqual = ts.isAtSameMomentAs(start) || ts.isAfter(start);
  final before = ts.isBefore(end); // end حصري
  return afterOrEqual && before;
}

bool _isUnpaidDeferred(Map<String, dynamic> m) {
  final isDeferred = (m['is_deferred'] ?? false) == true;
  final paid = (m['paid'] ?? (!isDeferred)) == true;
  return isDeferred && !paid;
}

/// ============ RAW الشهري + فلترة الثلث/الشهر ============

final statsSalesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final month = ref.watch(statsForMonthProvider);
  final period = ref.watch(statsSelectedPeriodProvider);

  // اسحب الشهر كله مرّة واحدة
  final rawMonth = await ref.watch(salesRawForMonthProvider(month).future);

  // فلتر بالمدى المحسوب (4ص → 4ص)
  final r = statsComputeRange(month, period);
  return rawMonth
      .where((m) => _inRangeUtc(_asUtc(m['created_at']), r.startUtc, r.endUtc))
      .toList();
});

/// المصروفات حسب المدى المختار
final statsExpensesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final r = ref.watch(statsRangeProvider);
  final snap = await FirebaseFirestore.instance
      .collection('expenses')
      .where('created_at', isGreaterThanOrEqualTo: r.startUtc)
      .where('created_at', isLessThan: r.endUtc)
      .get();

  return snap.docs.map((d) => d.data()).toList();
});

/// Preview للأثلاث/الشهر — **يستثني الأجل غير المدفوع** ويقرأ الربح من الداتا
final statsThirdsPreviewProvider =
    FutureProvider<({Kpis third1, Kpis third2, Kpis third3, Kpis month})>((
      ref,
    ) async {
      final month = ref.watch(statsForMonthProvider);
      final rawMonth = await ref.watch(salesRawForMonthProvider(month).future);

      Kpis kpisForRange(DateTime start, DateTime end) {
        double sales = 0, cost = 0, profit = 0, grams = 0;
        int cups = 0;
        int units = 0;
        for (final m in rawMonth) {
          final ts = _asUtc(m['created_at']);
          if (!_inRangeUtc(ts, start, end)) continue;
          if (_isUnpaidDeferred(m)) continue;

          final type = '${m['type'] ?? ''}';
          final price = (m['total_price'] is num)
              ? (m['total_price'] as num).toDouble()
              : _d(m['total_price']);
          final tcost = (m['total_cost'] is num)
              ? (m['total_cost'] as num).toDouble()
              : _d(m['total_cost']);
          final p = (m['profit_total'] is num)
              ? (m['profit_total'] as num).toDouble()
              : _d(m['profit_total']);

          sales += price;
          cost += tcost;
          profit += p;

          if (type == 'drink') {
            final q = (m['quantity'] is num)
                ? (m['quantity'] as num).toDouble()
                : _d(m['quantity']);
            cups += (q > 0 ? q.round() : 1);
          } else if (type == 'single' || type == 'ready_blend') {
            grams += (m['grams'] is num)
                ? (m['grams'] as num).toDouble()
                : _d(m['grams']);
          } else if (type == 'custom_blend') {
            grams += (m['total_grams'] is num)
                ? (m['total_grams'] as num).toDouble()
                : _d(m['total_grams']);
          }
        }
        return Kpis(
          sales: sales,
          cost: cost,
          profit: profit,
          cups: cups,
          grams: grams,
          expenses: 0,
          units: units,
        );
      }

      final r1 = statsComputeRange(month, StatsPeriod.firstThird);
      final r2 = statsComputeRange(month, StatsPeriod.secondThird);
      final r3 = statsComputeRange(month, StatsPeriod.thirdThird);
      final rm = statsComputeRange(month, StatsPeriod.fullMonth);

      return (
        third1: kpisForRange(r1.startUtc, r1.endUtc),
        third2: kpisForRange(r2.startUtc, r2.endUtc),
        third3: kpisForRange(r3.startUtc, r3.endUtc),
        month: kpisForRange(rm.startUtc, rm.endUtc),
      );
    });

/// ============ KPIs (الربح من الداتا + استبعاد الأجل غير المدفوع) ============
Kpis _buildKpis(
  List<Map<String, dynamic>> data,
  List<Map<String, dynamic>> expensesList,
) {
  double sales = 0, cost = 0, profit = 0, grams = 0;
  int cups = 0;
  int units = 0;

  for (final m in data) {
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    if (isDeferred && !paid) continue;

    final type = '${m['type'] ?? ''}';

    sales += _d(m['total_price']);
    cost += _d(m['total_cost']);
    profit += _d(m['profit_total']);

    if (type == 'drink') {
      final q = (m['quantity'] is num)
          ? (m['quantity'] as num).toDouble()
          : _d(m['quantity']);
      cups += (q > 0 ? q.round() : 1);
    } else if (type == 'single' || type == 'ready_blend') {
      grams += (m['grams'] is num)
          ? (m['grams'] as num).toDouble()
          : _d(m['grams']);
    } else if (type == 'custom_blend') {
      grams += (m['total_grams'] is num)
          ? (m['total_grams'] as num).toDouble()
          : _d(m['total_grams']);
    } else if (type == 'extra') {
      final q = (m['quantity'] is num)
          ? (m['quantity'] as num).toDouble()
          : _d(m['quantity']);
      units += (q > 0 ? q.round() : 1);
    }
  }

  final expensesSum = expensesList.fold<double>(
    0.0,
    (s, e) => s + _d(e['amount']),
  );

  return Kpis(
    sales: sales,
    cost: cost,
    profit: profit,
    cups: cups,
    grams: grams,
    expenses: expensesSum,
    units: units,
  );
}

final statsKpisProvider = FutureProvider<Kpis>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final expensesList = await ref.watch(statsExpensesProvider.future);
  return _buildKpis(data, expensesList);
});

/// ============ Extras (Snacks: معمول/تمر) by name ============
List<GroupRow> _buildExtrasRows(List<Map<String, dynamic>> data) {
  final map = <String, GroupRow>{};
  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;

    final type = '${m['type'] ?? ''}';
    final isExtra = type == 'extra' || m.containsKey('extra_id');
    if (!isExtra) continue;

    final name = ('${m['name'] ?? m['extra_name'] ?? 'سناكس'}').trim();
    final variant = ('${m['variant'] ?? ''}').trim();
    final key = variant.isEmpty ? name : '$name - $variant';

    final price =
        (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
    final cost = (m['total_cost'] as num?)?.toDouble() ?? _d(m['total_cost']);
    final profit =
        (m['profit_total'] as num?)?.toDouble() ?? _d(m['profit_total']);
    final qRaw = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
    final pieces = (qRaw > 0 ? qRaw.round() : 1);

    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(s: price, c: cost, p: profit, cu: pieces);
  }
  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

final extrasByNameProvider = FutureProvider<List<GroupRow>>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  return _buildExtrasRows(data);
});
StatsHighlights _buildHighlights(List<Map<String, dynamic>> data) {
  final Map<DateTime, double> salesByDay = {};
  final Map<DateTime, double> profitByDay = {};
  final Map<DateTime, int> servingsByDay = {};
  final Map<DateTime, Set<String>> ordersByDay = {};

  double totalSales = 0;
  int totalServings = 0;
  final uniqueOrders = <String>{};

  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;

    final ts = _asUtc(m['created_at']);
    final opDay = opDayKeyUtc(ts);

    final price =
        (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
    final profit =
        (m['profit_total'] as num?)?.toDouble() ?? _d(m['profit_total']);
    final type = '${m['type'] ?? ''}';

    int servings = 0;
    if (type == 'drink') {
      final q = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
      servings = (q > 0 ? q.round() : 1);
    } else {
      final isExtra = type == 'extra' || m.containsKey('extra_id');
      if (isExtra) {
        final q = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
        servings = (q > 0 ? q.round() : 1);
      }
    }

    final saleId = '${m['sale_id'] ?? m['id'] ?? ''}'.trim();
    if (saleId.isNotEmpty) {
      uniqueOrders.add(saleId);
      final set = ordersByDay.putIfAbsent(opDay, () => <String>{});
      set.add(saleId);
    }

    salesByDay[opDay] = (salesByDay[opDay] ?? 0) + price;
    profitByDay[opDay] = (profitByDay[opDay] ?? 0) + profit;

    if (servings > 0) {
      servingsByDay[opDay] = (servingsByDay[opDay] ?? 0) + servings;
      totalServings += servings;
    }

    totalSales += price;
  }

  DateTime? maxDayBySales;
  double maxSales = -1;
  salesByDay.forEach((day, value) {
    if (value > maxSales) {
      maxSales = value;
      maxDayBySales = day;
    }
  });

  DateTime? maxDayByProfit;
  double maxProfit = -1;
  profitByDay.forEach((day, value) {
    if (value > maxProfit) {
      maxProfit = value;
      maxDayByProfit = day;
    }
  });

  DateTime? maxDayByServings;
  int maxServings = -1;
  servingsByDay.forEach((day, value) {
    if (value > maxServings) {
      maxServings = value;
      maxDayByServings = day;
    }
  });

  DayHighlight? highlightFor(DateTime? day) {
    if (day == null) return null;
    return DayHighlight(
      day: day,
      sales: salesByDay[day] ?? 0,
      profit: profitByDay[day] ?? 0,
      servings: servingsByDay[day] ?? 0,
      orders: ordersByDay[day]?.length ?? 0,
    );
  }

  final activeDays = salesByDay.keys.length;
  final totalOrders = uniqueOrders.length;

  final avgOrderValue = totalOrders > 0 ? (totalSales / totalOrders) : 0.0;
  final avgDailySales = activeDays > 0 ? (totalSales / activeDays) : 0.0;

  return StatsHighlights(
    topSalesDay: highlightFor(maxDayBySales),
    topProfitDay: highlightFor(maxDayByProfit),
    busiestDay: highlightFor(maxDayByServings),
    averageOrderValue: avgOrderValue,
    averageDailySales: avgDailySales,
    totalOrders: totalOrders,
    activeDays: activeDays,
    totalServings: totalServings,
  );
}

final statsHighlightsProvider = FutureProvider<StatsHighlights>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  return _buildHighlights(data);
});

/// ============ Drinks/Beans by name ============

List<GroupRow> _buildDrinksRows(List<Map<String, dynamic>> data) {
  final map = <String, GroupRow>{};
  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;
    if ('${m['type'] ?? ''}' != 'drink') continue;

    final name = ('${m['drink_name'] ?? m['name'] ?? 'مشروب'}').trim();
    final variant = ('${m['variant'] ?? m['roast'] ?? ''}').trim();
    final key = variant.isEmpty ? name : '$name - $variant';

    final price =
        (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
    final cost = (m['total_cost'] as num?)?.toDouble() ?? _d(m['total_cost']);
    final profit =
        (m['profit_total'] as num?)?.toDouble() ?? _d(m['profit_total']);
    final qRaw = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
    final cups = (qRaw > 0 ? qRaw.round() : 1);

    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(s: price, c: cost, p: profit, cu: cups);
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

final drinksByNameProvider = FutureProvider<List<GroupRow>>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  return _buildDrinksRows(data);
});

/// يفكّك "توليفة العميل" ويجمع كل مكوّن باسمُه (name - variant)
List<GroupRow> _buildBeansRows(List<Map<String, dynamic>> data) {
  final map = <String, GroupRow>{};

  List<Map<String, dynamic>> asListMap(dynamic v) {
    if (v is List) {
      return v
          .map(
            (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
          )
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> normRow(Map<String, dynamic> c) {
    String name = (c['name'] ?? c['item_name'] ?? c['product_name'] ?? '')
        .toString();
    String variant = (c['variant'] ?? c['roast'] ?? '').toString();
    double grams = (c['grams'] is num)
        ? (c['grams'] as num).toDouble()
        : _d(c['grams']);
    double linePrice = (c['line_total_price'] is num)
        ? (c['line_total_price'] as num).toDouble()
        : _d(c['line_total_price']);
    double lineCost = (c['line_total_cost'] is num)
        ? (c['line_total_cost'] as num).toDouble()
        : _d(c['line_total_cost']);
    return {
      'name': name.trim(),
      'variant': variant.trim(),
      'grams': grams,
      'line_total_price': linePrice,
      'line_total_cost': lineCost,
    };
  }

  void addToMap({
    required String key,
    double grams = 0,
    double sales = 0,
    double cost = 0,
  }) {
    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(g: grams, s: sales, c: cost, p: (sales - cost), cu: 0);
  }

  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;
    final type = '${m['type'] ?? ''}';

    if (type == 'single' || type == 'ready_blend') {
      final name = ('${m['name'] ?? m['single_name'] ?? m['blend_name'] ?? ''}')
          .trim();
      final variant = ('${m['variant'] ?? m['roast'] ?? ''}').trim();
      final key = name.isEmpty
          ? 'بدون اسم'
          : (variant.isEmpty ? name : '$name - $variant');

      final grams = (m['grams'] as num?)?.toDouble() ?? _d(m['grams']);
      final price =
          (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
      final cost = (m['total_cost'] as num?)?.toDouble() ?? _d(m['total_cost']);

      addToMap(key: key, grams: grams, sales: price, cost: cost);
      continue;
    }

    if (type == 'custom_blend') {
      final comps = asListMap(m['components']);
      final items = asListMap(m['items']);
      final lines = asListMap(m['lines']);
      final rowsRaw = comps.isNotEmpty
          ? comps
          : (items.isNotEmpty ? items : lines);

      if (rowsRaw.isEmpty) {
        final gramsAll =
            (m['total_grams'] as num?)?.toDouble() ?? _d(m['total_grams']);
        final price =
            (m['lines_amount'] as num?)?.toDouble() ??
            (m['beans_amount'] as num?)?.toDouble() ??
            0.0;
        final cost = (m['total_cost'] as num?)?.toDouble() ?? 0.0;
        addToMap(key: 'مخصص', grams: gramsAll, sales: price, cost: cost);
        continue;
      }

      final rows = rowsRaw.map(normRow).toList();
      final totalGrams = rows.fold<double>(
        0,
        (s, r) => s + (r['grams'] as double),
      );
      final beansAmount =
          (m['lines_amount'] as num?)?.toDouble() ??
          (m['beans_amount'] as num?)?.toDouble() ??
          0.0;

      for (final r in rows) {
        final name = r['name'] as String;
        final variant = r['variant'] as String;
        final grams = r['grams'] as double;
        if (name.isEmpty && grams <= 0) continue;

        final key = (variant.isEmpty ? name : '$name - $variant').trim().isEmpty
            ? 'مكوّن'
            : (variant.isEmpty ? name : '$name - $variant');

        double linePrice = r['line_total_price'] as double;
        double lineCost = r['line_total_cost'] as double;

        if (linePrice <= 0 && beansAmount > 0 && totalGrams > 0) {
          linePrice = beansAmount * (grams / totalGrams);
        }

        addToMap(key: key, grams: grams, sales: linePrice, cost: lineCost);
      }
    }
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

final beansByNameProvider = FutureProvider<List<GroupRow>>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  return _buildBeansRows(data);
});

/// ============ Trends (مدفوع فقط + الربح من الداتا) ============

class TrendsBundle {
  final List<DayVal> totalSales;
  final List<DayVal> totalProfit;
  final List<DayVal> drinksSales;
  final List<DayVal> drinksProfit;
  final List<DayVal> beansSales;
  final List<DayVal> beansProfit;
  const TrendsBundle({
    required this.totalSales,
    required this.totalProfit,
    required this.drinksSales,
    required this.drinksProfit,
    required this.beansSales,
    required this.beansProfit,
  });
}

TrendsBundle _buildTrends(List<Map<String, dynamic>> data) {
  final Map<DateTime, double> salesM = {};
  final Map<DateTime, double> profitM = {};
  final Map<DateTime, double> drinksSalesM = {};
  final Map<DateTime, double> drinksProfitM = {};
  final Map<DateTime, double> beansSalesM = {};
  final Map<DateTime, double> beansProfitM = {};

  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;

    final ts = _asUtc(m['created_at']);
    final k = opDayKeyUtc(ts);
    final type = '${m['type'] ?? ''}';

    final price =
        (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
    final profit =
        (m['profit_total'] as num?)?.toDouble() ?? _d(m['profit_total']);

    salesM[k] = (salesM[k] ?? 0) + price;
    profitM[k] = (profitM[k] ?? 0) + profit;

    if (type == 'drink') {
      drinksSalesM[k] = (drinksSalesM[k] ?? 0) + price;
      drinksProfitM[k] = (drinksProfitM[k] ?? 0) + profit;
    } else {
      beansSalesM[k] = (beansSalesM[k] ?? 0) + price;
      beansProfitM[k] = (beansProfitM[k] ?? 0) + profit;
    }
  }

  List<DayVal> toList(Map<DateTime, double> mp) {
    final ks = mp.keys.toList()..sort();
    return ks.map((d) => DayVal(d, mp[d] ?? 0)).toList();
  }

  return TrendsBundle(
    totalSales: toList(salesM),
    totalProfit: toList(profitM),
    drinksSales: toList(drinksSalesM),
    drinksProfit: toList(drinksProfitM),
    beansSales: toList(beansSalesM),
    beansProfit: toList(beansProfitM),
  );
}

final statsTrendsProvider = FutureProvider<TrendsBundle>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  return _buildTrends(data);
});

final statsOverviewProvider = FutureProvider<StatsOverview>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final expenses = await ref.watch(statsExpensesProvider.future);
  return StatsOverview(
    kpis: _buildKpis(data, expenses),
    drinks: _buildDrinksRows(data),
    beans: _buildBeansRows(data),
    extras: _buildExtrasRows(data),
    trends: _buildTrends(data),
    highlights: _buildHighlights(data),
  );
});

// دالة بتعمل Refresh لكل الداتا من السورس
Future<void> refreshStatsProviders(WidgetRef ref) async {
  ref.invalidate(statsSalesProvider);
  ref.invalidate(statsExpensesProvider);
  ref.invalidate(statsKpisProvider);
  ref.invalidate(drinksByNameProvider);
  ref.invalidate(beansByNameProvider);
  ref.invalidate(statsTrendsProvider);
  ref.invalidate(extrasByNameProvider);
  ref.invalidate(statsHighlightsProvider);
  ref.invalidate(statsOverviewProvider);

  // كمان بنعمل invalidate للكاش الخام الشهري (family)
  ref.invalidate(salesRawForMonthProvider);
  await Future.delayed(const Duration(milliseconds: 1));
}
