// ignore_for_file: unused_element

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
  final double plainGrams;
  final double spicedGrams;
  final int cups;
  const GroupRow({
    required this.key,
    this.sales = 0,
    this.cost = 0,
    this.profit = 0,
    this.grams = 0,
    this.plainGrams = 0,
    this.spicedGrams = 0,
    this.cups = 0,
  });

  String get name => key;

  GroupRow add({
    double s = 0,
    double c = 0,
    double p = 0,
    double g = 0,
    double gPlain = 0,
    double gSpiced = 0,
    int cu = 0,
  }) => GroupRow(
    key: key,
    sales: sales + s,
    cost: cost + c,
    profit: profit + p,
    grams: grams + g,
    plainGrams: plainGrams + gPlain,
    spicedGrams: spicedGrams + gSpiced,
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
  final double averageDailySales;
  final double averageDrinksPerDay;
  final double averageSnacksPerDay;
  final double averageOrdersPerDay;
  final int totalOrders;
  final int activeDays;
  const StatsHighlights({
    required this.topSalesDay,
    required this.topProfitDay,
    required this.busiestDay,
    required this.averageDailySales,
    required this.averageDrinksPerDay,
    required this.averageSnacksPerDay,
    required this.averageOrdersPerDay,
    required this.totalOrders,
    required this.activeDays,
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

DateTime _productionUtc(Map<String, dynamic> m) {
  final orig = m['original_created_at'];
  final origUtc = orig == null ? null : _asUtc(orig);
  if (origUtc != null && origUtc.millisecondsSinceEpoch > 0) return origUtc;
  return _asUtc(m['created_at']);
}

DateTime _financialUtc(Map<String, dynamic> m) {
  final created = _asUtc(m['created_at']);
  final settledRaw = m['settled_at'];
  final settled = settledRaw == null ? null : _asUtc(settledRaw);
  final updatedRaw = m['updated_at'];
  final updated = updatedRaw == null ? null : _asUtc(updatedRaw);

  final isDeferred = (m['is_deferred'] ?? false) == true;
  final paid = (m['paid'] ?? (!isDeferred)) == true;

  if (paid) {
    if (settled != null && settled.millisecondsSinceEpoch > 0) {
      return settled;
    }
    if (updated != null && updated.millisecondsSinceEpoch > 0) {
      return updated;
    }
  }
  return created;
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

bool _inProductionRange(Map<String, dynamic> m, DateTime start, DateTime end) =>
    _inRangeUtc(_productionUtc(m), start, end);

bool _inFinancialRange(Map<String, dynamic> m, DateTime start, DateTime end) =>
    _inRangeUtc(_financialUtc(m), start, end);

/// ============ RAW الشهري + فلترة الثلث/الشهر ============

final statsSalesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final month = ref.watch(statsForMonthProvider);
  final period = ref.watch(statsSelectedPeriodProvider);

  // OO3O-O" OU,O'U?O? U?U,U? U.O?U`Oc U^OO-O_Oc
  final rawMonth = await ref.watch(salesRawForMonthProvider(month).future);

  // U?U,O?O? O"OU,U.O_U% OU,U.O-O3U^O" (4O? ?+' 4O?)
  final r = statsComputeRange(month, period);
  return rawMonth.where((m) {
    final inProd = _inProductionRange(m, r.startUtc, r.endUtc);
    final inFin = _inFinancialRange(m, r.startUtc, r.endUtc);
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    if (isDeferred && !paid) return inProd;
    return inProd || inFin;
  }).toList();
});
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
        return _buildKpis(rawMonth, const [], startUtc: start, endUtc: end);
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
  List<Map<String, dynamic>> expensesList, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  double sales = 0, cost = 0, profit = 0, grams = 0;
  int cups = 0;
  int units = 0;

  for (final m in data) {
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final finInRange = _inFinancialRange(m, startUtc, endUtc);
    if (!prodInRange && !finInRange) continue;

    final type = '${m['type'] ?? ''}';

    if (finInRange && (!isDeferred || paid)) {
      sales += _d(m['total_price']);
      cost += _d(m['total_cost']);
      profit += _d(m['profit_total']);
    }

    if (prodInRange) {
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
  final range = ref.watch(statsRangeProvider);
  final data = await ref.watch(statsSalesProvider.future);
  final expensesList = await ref.watch(statsExpensesProvider.future);
  return _buildKpis(
    data,
    expensesList,
    startUtc: range.startUtc,
    endUtc: range.endUtc,
  );
});

/// ============ Extras (Snacks: U.O1U.U^U,/O?U.O?) by name ============
List<GroupRow> _buildExtrasRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final map = <String, GroupRow>{};
  for (final m in data) {
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final finInRange = _inFinancialRange(m, startUtc, endUtc);
    if (!prodInRange && !finInRange) continue;

    final type = '${m['type'] ?? ''}';
    final isExtra = type == 'extra' || m.containsKey('extra_id');
    if (!isExtra) continue;

    final name = ('${m['name'] ?? m['extra_name'] ?? 'O3U+OU?O3'}').trim();
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
    map[key] = base.add(
      s: (finInRange && (!isDeferred || paid)) ? price : 0,
      c: (finInRange && (!isDeferred || paid)) ? cost : 0,
      p: (finInRange && (!isDeferred || paid)) ? profit : 0,
      cu: prodInRange ? pieces : 0,
    );
  }
  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

final extrasByNameProvider = FutureProvider<List<GroupRow>>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final range = ref.watch(statsRangeProvider);
  return _buildExtrasRows(data, startUtc: range.startUtc, endUtc: range.endUtc);
});

StatsHighlights _buildHighlights(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final Map<DateTime, double> salesByDay = {};
  final Map<DateTime, double> profitByDay = {};
  final Map<DateTime, int> servingsByDay = {};
  final Map<DateTime, Set<String>> ordersByDay = {};

  double totalSales = 0;
  int totalDrinkServings = 0;
  int totalSnackServings = 0;
  final uniqueOrders = <String>{};

  for (final m in data) {
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final finInRange = _inFinancialRange(m, startUtc, endUtc);
    if (!prodInRange && !finInRange) continue;

    final finDay = opDayKeyUtc(_financialUtc(m));
    final prodDay = opDayKeyUtc(_productionUtc(m));

    if (finInRange && (!isDeferred || paid)) {
      final price =
          (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
      final profit =
          (m['profit_total'] as num?)?.toDouble() ?? _d(m['profit_total']);

      final saleId = '${m['sale_id'] ?? m['id'] ?? ''}'.trim();
      if (saleId.isNotEmpty) {
        uniqueOrders.add(saleId);
        final set = ordersByDay.putIfAbsent(finDay, () => <String>{});
        set.add(saleId);
      }

      salesByDay[finDay] = (salesByDay[finDay] ?? 0) + price;
      profitByDay[finDay] = (profitByDay[finDay] ?? 0) + profit;
      totalSales += price;
    }

    if (prodInRange) {
      final type = '${m['type'] ?? ''}';
      int servings = 0;
      if (type == 'drink') {
        final q = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
        servings = (q > 0 ? q.round() : 1);
        totalDrinkServings += servings;
      } else {
        final isExtra = type == 'extra' || m.containsKey('extra_id');
        if (isExtra) {
          final q = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
          servings = (q > 0 ? q.round() : 1);
          totalSnackServings += servings;
        }
      }

      if (servings > 0) {
        servingsByDay[prodDay] = (servingsByDay[prodDay] ?? 0) + servings;
      }
    }
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

  DayHighlight? highlightFor(
    DateTime? day, {
    required Map<DateTime, double> bySales,
    required Map<DateTime, double> byProfit,
    required Map<DateTime, int> byServings,
    required Map<DateTime, Set<String>> byOrders,
  }) {
    if (day == null) return null;
    return DayHighlight(
      day: day,
      sales: bySales[day] ?? 0,
      profit: byProfit[day] ?? 0,
      servings: byServings[day] ?? 0,
      orders: byOrders[day]?.length ?? 0,
    );
  }

  final activeSalesDays = salesByDay.keys.length;
  final activeProdDays = servingsByDay.keys.length;
  final totalOrders = uniqueOrders.length;

  final avgDailySales = activeSalesDays > 0
      ? (totalSales / activeSalesDays)
      : 0.0;
  final avgDrinksPerDay = activeProdDays > 0
      ? (totalDrinkServings / activeProdDays)
      : 0.0;
  final avgSnacksPerDay = activeProdDays > 0
      ? (totalSnackServings / activeProdDays)
      : 0.0;
  final avgOrdersPerDay = activeSalesDays > 0
      ? (totalOrders / activeSalesDays)
      : 0.0;

  return StatsHighlights(
    topSalesDay: highlightFor(
      maxDayBySales,
      bySales: salesByDay,
      byProfit: profitByDay,
      byServings: servingsByDay,
      byOrders: ordersByDay,
    ),
    topProfitDay: highlightFor(
      maxDayByProfit,
      bySales: salesByDay,
      byProfit: profitByDay,
      byServings: servingsByDay,
      byOrders: ordersByDay,
    ),
    busiestDay: highlightFor(
      maxDayByServings,
      bySales: salesByDay,
      byProfit: profitByDay,
      byServings: servingsByDay,
      byOrders: ordersByDay,
    ),
    averageDailySales: avgDailySales,
    averageDrinksPerDay: avgDrinksPerDay,
    averageSnacksPerDay: avgSnacksPerDay,
    averageOrdersPerDay: avgOrdersPerDay,
    totalOrders: totalOrders,
    activeDays: activeSalesDays,
  );
}

final statsHighlightsProvider = FutureProvider<StatsHighlights>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final range = ref.watch(statsRangeProvider);
  return _buildHighlights(data, startUtc: range.startUtc, endUtc: range.endUtc);
});

/// ============ Drinks/Beans by name ============

List<GroupRow> _buildDrinksRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final map = <String, GroupRow>{};
  for (final m in data) {
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final finInRange = _inFinancialRange(m, startUtc, endUtc);
    if (!prodInRange && !finInRange) continue;
    if ('${m['type'] ?? ''}' != 'drink') continue;

    final name =
        ('${m['drink_name'] ?? m['name'] ?? 'U.O'
                    'O?U^O"'}')
            .trim();
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
    map[key] = base.add(
      s: (finInRange && (!isDeferred || paid)) ? price : 0,
      c: (finInRange && (!isDeferred || paid)) ? cost : 0,
      p: (finInRange && (!isDeferred || paid)) ? profit : 0,
      cu: prodInRange ? cups : 0,
    );
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

final drinksByNameProvider = FutureProvider<List<GroupRow>>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final range = ref.watch(statsRangeProvider);
  return _buildDrinksRows(data, startUtc: range.startUtc, endUtc: range.endUtc);
});

/// USU?U?U`U? "O?U^U,USU?Oc OU,O1U.USU," U^USO?U.O1 U?U, U.U?U^U`U+ O"OO3U.U?U? (name - variant)
List<GroupRow> _buildBeansRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
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

  Map<String, dynamic> normRow(
    Map<String, dynamic> c, {
    required bool fallbackSpiced,
  }) {
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
    final isSpiced = (c['is_spiced'] ?? fallbackSpiced) == true;
    return {
      'name': name.trim(),
      'variant': variant.trim(),
      'grams': grams,
      'line_total_price': linePrice,
      'line_total_cost': lineCost,
      'is_spiced': isSpiced,
    };
  }

  void addToMap({
    required String key,
    double grams = 0,
    double sales = 0,
    double cost = 0,
    bool isSpiced = false,
  }) {
    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(
      g: grams,
      gPlain: isSpiced ? 0 : grams,
      gSpiced: isSpiced ? grams : 0,
      s: sales,
      c: cost,
      p: (sales - cost),
      cu: 0,
    );
  }

  for (final m in data) {
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final finInRange = _inFinancialRange(m, startUtc, endUtc);
    if (!prodInRange && !finInRange) continue;
    final includeGrams = prodInRange;
    final includeMoney = finInRange && (!isDeferred || paid);

    final type = '${m['type'] ?? ''}';
    final saleIsSpiced = (m['is_spiced'] ?? false) == true;

    if (type == 'single' || type == 'ready_blend') {
      final name = ('${m['name'] ?? m['single_name'] ?? m['blend_name'] ?? ''}')
          .trim();
      final variant = ('${m['variant'] ?? m['roast'] ?? ''}').trim();
      final key = name.isEmpty
          ? 'O"O_U^U+ OO3U.'
          : (variant.isEmpty ? name : '$name - $variant');

      final grams = (m['grams'] as num?)?.toDouble() ?? _d(m['grams']);
      final price =
          (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
      final cost = (m['total_cost'] as num?)?.toDouble() ?? _d(m['total_cost']);

      addToMap(
        key: key,
        grams: includeGrams ? grams : 0,
        sales: includeMoney ? price : 0,
        cost: includeMoney ? cost : 0,
        isSpiced: saleIsSpiced,
      );
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
        addToMap(
          key: 'U.OrO?O?',
          grams: includeGrams ? gramsAll : 0,
          sales: includeMoney ? price : 0,
          cost: includeMoney ? cost : 0,
          isSpiced: saleIsSpiced,
        );
        continue;
      }

      final rows = rowsRaw
          .map((r) => normRow(r, fallbackSpiced: saleIsSpiced))
          .toList();
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
        final isRowSpiced = (r['is_spiced'] as bool?) ?? saleIsSpiced;
        if (name.isEmpty && grams <= 0) continue;

        final key = (variant.isEmpty ? name : '$name - $variant').trim().isEmpty
            ? 'U.U?U^U`U+'
            : (variant.isEmpty ? name : '$name - $variant');

        double linePrice = r['line_total_price'] as double;
        double lineCost = r['line_total_cost'] as double;

        if (linePrice <= 0 && beansAmount > 0 && totalGrams > 0) {
          linePrice = beansAmount * (grams / totalGrams);
        }

        addToMap(
          key: key,
          grams: includeGrams ? grams : 0,
          sales: includeMoney ? linePrice : 0,
          cost: includeMoney ? lineCost : 0,
          isSpiced: isRowSpiced,
        );
      }
    }
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

final beansByNameProvider = FutureProvider<List<GroupRow>>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final range = ref.watch(statsRangeProvider);
  return _buildBeansRows(data, startUtc: range.startUtc, endUtc: range.endUtc);
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

TrendsBundle _buildTrends(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final Map<DateTime, double> salesM = {};
  final Map<DateTime, double> profitM = {};
  final Map<DateTime, double> drinksSalesM = {};
  final Map<DateTime, double> drinksProfitM = {};
  final Map<DateTime, double> beansSalesM = {};
  final Map<DateTime, double> beansProfitM = {};

  for (final m in data) {
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    final finInRange = _inFinancialRange(m, startUtc, endUtc);
    if (!finInRange || (isDeferred && !paid)) continue;

    final k = opDayKeyUtc(_financialUtc(m));
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
  final range = ref.watch(statsRangeProvider);
  return _buildTrends(data, startUtc: range.startUtc, endUtc: range.endUtc);
});

final statsOverviewProvider = FutureProvider<StatsOverview>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final expenses = await ref.watch(statsExpensesProvider.future);
  final range = ref.watch(statsRangeProvider);
  return StatsOverview(
    kpis: _buildKpis(
      data,
      expenses,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    ),
    drinks: _buildDrinksRows(
      data,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    ),
    beans: _buildBeansRows(
      data,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    ),
    extras: _buildExtrasRows(
      data,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    ),
    trends: _buildTrends(data, startUtc: range.startUtc, endUtc: range.endUtc),
    highlights: _buildHighlights(
      data,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    ),
  );
});
// Refresh لكل الداتا من السورس
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
