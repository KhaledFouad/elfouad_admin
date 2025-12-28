// ignore_for_file: unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:elfouad_admin/core/app_strings.dart';

import '../utils/op_day.dart';
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

const Set<String> _knownTypes = {
  'drink',
  'single',
  'ready_blend',
  'custom_blend',
  'extra',
};

bool _isKnownType(String t) => _knownTypes.contains(t);

double? _numIfPresent(Map<String, dynamic> m, String key) {
  if (!m.containsKey(key)) return null;
  final v = m[key];
  if (v == null) return null;
  return _d(v);
}

bool _hasAnyKey(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null) return true;
  }
  return false;
}

double _pickNum(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = _numIfPresent(m, k);
    if (v != null) return v;
  }
  return 0.0;
}

String _pickStr(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (!m.containsKey(k)) continue;
    final v = m[k];
    if (v == null) continue;
    return v.toString();
  }
  return '';
}

List<Map<String, dynamic>> _asListMap(dynamic v) {
  if (v is List) {
    return v
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .toList();
  }
  return const [];
}

List<Map<String, dynamic>> _extractLineItems(Map<String, dynamic> m) {
  return [
    ..._asListMap(m['components']),
    ..._asListMap(m['items']),
    ..._asListMap(m['lines']),
    ..._asListMap(m['cart_items']),
    ..._asListMap(m['order_items']),
    ..._asListMap(m['products']),
  ];
}

Map<String, dynamic> _normalizeLineItem(Map<String, dynamic> c) {
  final out = Map<String, dynamic>.from(c);
  final qty = _pickNum(out, ['qty', 'quantity', 'count', 'pieces']);
  final grams = _pickNum(out, ['grams', 'weight', 'gram', 'total_grams']);
  final unit = _pickStr(out, ['unit', 'uom', 'unit_name']);
  const priceKeys = [
    'line_total_price',
    'total_price',
    'price',
    'line_price',
    'amount',
    'total',
    'subtotal',
  ];
  const costKeys = [
    'line_total_cost',
    'total_cost',
    'cost',
    'line_cost',
    'cost_amount',
  ];
  final hasLinePrice = _hasAnyKey(out, priceKeys);
  final hasLineCost = _hasAnyKey(out, costKeys);
  var linePrice = _pickNum(out, priceKeys);
  var lineCost = _pickNum(out, costKeys);
  final unitPrice = _pickNum(out, ['unit_price', 'price_per_unit']);
  final unitCost = _pickNum(out, ['unit_cost', 'cost_per_unit']);

  if (!hasLinePrice && unitPrice > 0 && qty > 0) {
    linePrice = unitPrice * qty;
  }
  if (!hasLineCost && unitCost > 0 && qty > 0) {
    lineCost = unitCost * qty;
  }

  final name = _pickStr(
    out,
    ['name', 'item_name', 'product_name', 'drink_name', 'single_name', 'blend_name', 'title'],
  ).trim();
  final variant = _pickStr(out, ['variant', 'roast', 'size']).trim();
  final unitValue = unit.isNotEmpty ? unit : (grams > 0 ? 'g' : '');

  if (name.isNotEmpty) {
    out['name'] = name;
  } else {
    out.remove('name');
  }
  if (variant.isNotEmpty) {
    out['variant'] = variant;
  } else {
    out.remove('variant');
  }
  out['qty'] = qty;
  out['quantity'] = qty;
  out['grams'] = grams;
  if (unitValue.isNotEmpty) {
    out['unit'] = unitValue;
  } else {
    out.remove('unit');
  }
  out['line_total_price'] = linePrice;
  out['line_total_cost'] = lineCost;
  return out;
}

String _inferLineType(Map<String, dynamic> c, {String? fallbackType}) {
  final raw = (c['type'] ?? c['line_type'] ?? c['item_type'] ?? '').toString();
  if (_isKnownType(raw)) return raw;

  if (c.containsKey('extra_id') || (c['is_extra'] ?? false) == true) {
    return 'extra';
  }
  final unit = (c['unit'] ?? '').toString();
  if (unit == 'piece') return 'extra';

  if (c.containsKey('drink_id') || c.containsKey('drink_name')) {
    return 'drink';
  }
  if (c.containsKey('blend_id') ||
      c.containsKey('blend_name') ||
      c['lines_type'] == 'ready_blend') {
    return 'ready_blend';
  }
  if (c.containsKey('single_id') ||
      c.containsKey('single_name') ||
      c['lines_type'] == 'single') {
    return 'single';
  }

  final grams = _d(c['grams']);
  if (grams > 0) return 'single';
  final qty = _d(c['qty'] ?? c['quantity']);
  if (qty > 0) return 'drink';

  return fallbackType ?? 'unknown';
}

Map<String, dynamic> _applyTotalsFallback(
  Map<String, dynamic> m, {
  List<Map<String, dynamic>>? lines,
}) {
  final out = Map<String, dynamic>.from(m);
  final isComplimentary = (out['is_complimentary'] ?? false) == true;

  double price = _pickNum(out, ['total_price']);
  if (price <= 0) {
    price = _pickNum(out, ['total', 'total_amount', 'amount', 'grand_total']);
  }
  double cost = _pickNum(out, ['total_cost']);
  if (cost <= 0) {
    cost = _pickNum(out, ['total_cost_amount', 'cost', 'totalCost']);
  }
  double profit = _pickNum(out, ['profit_total', 'profit']);

  if (lines != null && lines.isNotEmpty) {
    final linePrice =
        lines.fold<double>(0.0, (s, r) => s + _d(r['line_total_price']));
    final lineCost =
        lines.fold<double>(0.0, (s, r) => s + _d(r['line_total_cost']));
    if (price <= 0 && linePrice > 0) price = linePrice;
    if (cost <= 0 && lineCost > 0) cost = lineCost;
  }

  if (isComplimentary) {
    price = 0.0;
    profit = 0.0;
  }

  if (profit == 0 && (price > 0 || cost > 0)) {
    profit = price - cost;
  }

  if (price > 0 || out.containsKey('total_price')) out['total_price'] = price;
  if (cost > 0 || out.containsKey('total_cost')) out['total_cost'] = cost;
  if (profit != 0 || out.containsKey('profit_total')) {
    out['profit_total'] = profit;
  }
  return out;
}

List<Map<String, dynamic>> _expandCartSales(List<Map<String, dynamic>> data) {
  final out = <Map<String, dynamic>>[];
  for (final m in data) {
    final fixed = _applyTotalsFallback(m);
    final type = (fixed['type'] ?? '').toString();
    final rawLines = _extractLineItems(fixed);
    final isComplimentary = (fixed['is_complimentary'] ?? false) == true;

    if (rawLines.isEmpty || _isKnownType(type)) {
      out.add(fixed);
      continue;
    }

    final lines = rawLines.map(_normalizeLineItem).toList();
    final lineTotal =
        lines.fold<double>(0.0, (s, r) => s + _d(r['line_total_price']));
    final lineCostTotal =
        lines.fold<double>(0.0, (s, r) => s + _d(r['line_total_cost']));
    final parentTotal = _d(fixed['total_price']);
    final tolerance = parentTotal > 0 ? parentTotal * 0.01 : 0.0;
    final withinTolerance =
        parentTotal <= 0 || (lineTotal - parentTotal).abs() <= tolerance;
    final hasLineValue = lineTotal > 0 || lineCostTotal > 0;
    final shouldExpand = isComplimentary ? lines.isNotEmpty : hasLineValue;
    if (!shouldExpand || (!isComplimentary && !withinTolerance)) {
      out.add(_applyTotalsFallback(fixed, lines: lines));
      continue;
    }

    final saleId = (fixed['sale_id'] ?? fixed['id'] ?? '').toString();
    for (final line in lines) {
      final lineType = _inferLineType(line, fallbackType: type.isNotEmpty ? type : null);
      final merged = Map<String, dynamic>.from(fixed);
      merged.addAll(line);
      merged['type'] = lineType;
      if (saleId.isNotEmpty) merged['sale_id'] = saleId;

      var linePrice = _d(line['line_total_price']);
      final lineCost = _d(line['line_total_cost']);
      if (isComplimentary) {
        linePrice = 0.0;
      }
      merged['total_price'] = linePrice;
      merged['total_cost'] = lineCost;
      merged['profit_total'] = linePrice - lineCost;

      if (lineType == 'drink' || lineType == 'extra') {
        final qty = _d(line['qty'] ?? line['quantity']);
        if (qty > 0) merged['quantity'] = qty;
      }
      if (lineType == 'single' || lineType == 'ready_blend') {
        final grams = _d(line['grams']);
        if (grams > 0) merged['grams'] = grams;
      }

      out.add(merged);
    }
  }
  return out;
}

List<Map<String, dynamic>> _prepareStatsData(List<Map<String, dynamic>> data) {
  return _expandCartSales(data);
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
  if (v is num) {
    final raw = v.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
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
Future<List<Map<String, dynamic>>> _fetchSalesRawForMonth(
  DateTime month,
) async {
  final y = month.year;
  final m = month.month;
  final dim = DateUtils.getDaysInMonth(y, m);

  final startUtc = DateTime(y, m, 1, 4).toUtc();
  final endUtc = DateTime(
    y,
    m,
    dim,
    4,
  ).add(const Duration(days: 1)).toUtc();
  final startIso = startUtc.toIso8601String();
  final endIso = endUtc.toIso8601String();
  final startMs = startUtc.millisecondsSinceEpoch;
  final endMs = endUtc.millisecondsSinceEpoch;

  final snap = await FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isGreaterThanOrEqualTo: startUtc)
      .where('created_at', isLessThan: endUtc)
      .orderBy('created_at', descending: false)
      .get();
  QuerySnapshot<Map<String, dynamic>>? snapStr;
  try {
    snapStr = await FirebaseFirestore.instance
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: startIso)
        .where('created_at', isLessThan: endIso)
        .orderBy('created_at', descending: false)
        .get();
  } catch (_) {
    snapStr = null;
  }
  QuerySnapshot<Map<String, dynamic>>? snapNum;
  try {
    snapNum = await FirebaseFirestore.instance
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: startMs)
        .where('created_at', isLessThan: endMs)
        .orderBy('created_at', descending: false)
        .get();
  } catch (_) {
    snapNum = null;
  }

  QuerySnapshot<Map<String, dynamic>>? snapOrig;
  try {
    snapOrig = await FirebaseFirestore.instance
        .collection('sales')
        .where('original_created_at', isGreaterThanOrEqualTo: startUtc)
        .where('original_created_at', isLessThan: endUtc)
        .orderBy('original_created_at', descending: false)
        .get();
  } catch (_) {
    snapOrig = null;
  }

  final combined = <String, Map<String, dynamic>>{};

  for (final d in snap.docs) {
    final m = d.data();
    m['id'] = d.id;
    combined[d.id] = m;
  }

  if (snapStr != null) {
    for (final d in snapStr.docs) {
      final m = d.data();
      m['id'] = d.id;
      combined[d.id] = m;
    }
  }
  if (snapNum != null) {
    for (final d in snapNum.docs) {
      final m = d.data();
      m['id'] = d.id;
      combined[d.id] = m;
    }
  }

  if (snapOrig != null) {
    for (final d in snapOrig.docs) {
      final m = d.data();
      m['id'] = d.id;
      combined[d.id] = m;
    }
  }

  return combined.values.toList();
}

List<Map<String, dynamic>> _filterStatsSales(
  List<Map<String, dynamic>> rawMonth, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  return rawMonth.where((m) {
    final inProd = _inProductionRange(m, startUtc, endUtc);
    final inFin = _inFinancialRange(m, startUtc, endUtc);
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    if (isDeferred && !paid) return inProd;
    return inProd || inFin;
  }).toList();
}

Future<List<Map<String, dynamic>>> _fetchStatsExpenses({
  required DateTime startUtc,
  required DateTime endUtc,
}) async {
  final snap = await FirebaseFirestore.instance
      .collection('expenses')
      .where('created_at', isGreaterThanOrEqualTo: startUtc)
      .where('created_at', isLessThan: endUtc)
      .get();

  return snap.docs.map((d) => d.data()).toList();
}
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

    final name =
        ('${m['name'] ?? m['extra_name'] ?? AppStrings.noNameLabel}').trim();
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
    double grams = _pickNum(c, ['grams', 'weight', 'gram', 'total_grams']);
    double linePrice = _pickNum(
      c,
      [
        'line_total_price',
        'total_price',
        'price',
        'line_price',
        'amount',
        'total',
        'subtotal',
      ],
    );
    double lineCost = _pickNum(
      c,
      [
        'line_total_cost',
        'total_cost',
        'cost',
        'line_cost',
        'cost_amount',
      ],
    );
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

class ThirdsPreview {
  final Kpis firstThird;
  final Kpis secondThird;
  final Kpis thirdThird;
  final Kpis month;
  const ThirdsPreview({
    required this.firstThird,
    required this.secondThird,
    required this.thirdThird,
    required this.month,
  });
}

class StatsState {
  final DateTime month;
  final StatsPeriod period;
  final StatsOverview? overview;
  final ThirdsPreview? preview;
  final bool loading;
  final bool previewLoading;
  final Object? error;
  final Object? previewError;

  const StatsState({
    required this.month,
    required this.period,
    required this.overview,
    required this.preview,
    required this.loading,
    required this.previewLoading,
    required this.error,
    required this.previewError,
  });

  StatsState copyWith({
    DateTime? month,
    StatsPeriod? period,
    StatsOverview? overview,
    ThirdsPreview? preview,
    bool? loading,
    bool? previewLoading,
    Object? error,
    Object? previewError,
  }) {
    return StatsState(
      month: month ?? this.month,
      period: period ?? this.period,
      overview: overview ?? this.overview,
      preview: preview ?? this.preview,
      loading: loading ?? this.loading,
      previewLoading: previewLoading ?? this.previewLoading,
      error: error,
      previewError: previewError,
    );
  }
}

class StatsCubit extends Cubit<StatsState> {
  StatsCubit()
      : super(
          StatsState(
            month: defaultStatsMonth(),
            period: defaultStatsPeriod(),
            overview: null,
            preview: null,
            loading: true,
            previewLoading: true,
            error: null,
            previewError: null,
          ),
        ) {
    _loadMonth(state.month, state.period);
  }

  List<Map<String, dynamic>> _rawMonth = const [];

  Future<void> refresh() => _loadMonth(state.month, state.period);

  Future<void> setMonth(DateTime month) =>
      _loadMonth(DateTime(month.year, month.month, 1), state.period);

  Future<void> setPeriod(StatsPeriod period) async {
    emit(state.copyWith(period: period, loading: true, error: null));
    await _computeOverview(period, state.month);
  }

  Future<void> _loadMonth(DateTime month, StatsPeriod period) async {
    emit(
      state.copyWith(
        month: month,
        period: period,
        loading: true,
        previewLoading: true,
        error: null,
        previewError: null,
      ),
    );
    try {
      _rawMonth = _prepareStatsData(await _fetchSalesRawForMonth(month));
      final preview = _buildThirdsPreview(_rawMonth, month);
      emit(
        state.copyWith(
          preview: preview,
          previewLoading: false,
          previewError: null,
        ),
      );
      await _computeOverview(period, month);
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          previewLoading: false,
          error: e,
          previewError: e,
        ),
      );
    }
  }

  Future<void> _computeOverview(StatsPeriod period, DateTime month) async {
    try {
      final range = statsComputeRange(month, period);
      final data = _filterStatsSales(
        _rawMonth,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      );
      final expenses = await _fetchStatsExpenses(
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      );
      final overview = StatsOverview(
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
        trends: _buildTrends(
          data,
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        ),
        highlights: _buildHighlights(
          data,
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        ),
      );
      emit(state.copyWith(overview: overview, loading: false, error: null));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e));
    }
  }

  ThirdsPreview _buildThirdsPreview(
    List<Map<String, dynamic>> rawMonth,
    DateTime month,
  ) {
    Kpis kpisForRange(DateTime start, DateTime end) {
      return _buildKpis(rawMonth, const [], startUtc: start, endUtc: end);
    }

    final r1 = statsComputeRange(month, StatsPeriod.firstThird);
    final r2 = statsComputeRange(month, StatsPeriod.secondThird);
    final r3 = statsComputeRange(month, StatsPeriod.thirdThird);
    final rm = statsComputeRange(month, StatsPeriod.fullMonth);

    return ThirdsPreview(
      firstThird: kpisForRange(r1.startUtc, r1.endUtc),
      secondThird: kpisForRange(r2.startUtc, r2.endUtc),
      thirdThird: kpisForRange(r3.startUtc, r3.endUtc),
      month: kpisForRange(rm.startUtc, rm.endUtc),
    );
  }
}


