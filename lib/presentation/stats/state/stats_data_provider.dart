import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/op_day.dart';
import 'sales_raw_provider.dart';
import 'stats_period.dart';

/// ============ Models ============

class Kpis {
  final double sales, cost, profit, grams;
  final int cups;
  final double expenses;
  const Kpis({
    required this.sales,
    required this.cost,
    required this.profit,
    required this.cups,
    required this.grams,
    required this.expenses,
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

/// ============ Helpers ============

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

DateTime _asUtc(dynamic v) {
  if (v is DateTime) return v.toUtc();
  try {
    // Firestore Timestamp
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

/// ============ RAW الشهري + فلترة الثلث/الشهر ============

final statsSalesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final month = ref.watch(statsForMonthProvider);
  final period = ref.watch(statsSelectedPeriodProvider);

  // اسحب الشهر كله مرّة واحدة (أسرع + أقل تكلفة)
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

/// Preview للأثلاث كلها عشان الـ chips تعرض أرقام صحيحة
final statsThirdsPreviewProvider =
    FutureProvider<({Kpis third1, Kpis third2, Kpis third3, Kpis month})>((
      ref,
    ) async {
      final month = ref.watch(statsForMonthProvider);
      final rawMonth = await ref.watch(salesRawForMonthProvider(month).future);

      Kpis kpisForRange(DateTime start, DateTime end) {
        double sales = 0, cost = 0, grams = 0;
        int cups = 0;
        for (final m in rawMonth) {
          final ts = _asUtc(m['created_at']);
          if (!_inRangeUtc(ts, start, end)) continue;

          final type = '${m['type'] ?? ''}';
          final price = (m['total_price'] is num)
              ? (m['total_price'] as num).toDouble()
              : _d(m['total_price']);
          final tcost = (m['total_cost'] is num)
              ? (m['total_cost'] as num).toDouble()
              : _d(m['total_cost']);
          sales += price;
          cost += tcost;

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
          profit: sales - cost,
          cups: cups,
          grams: grams,
          expenses: 0, // preview سريع
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

/// ============ KPIs للثلث/الشهر المختار (بالمصروفات) ============

final statsKpisProvider = FutureProvider<Kpis>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final expensesList = await ref.watch(statsExpensesProvider.future);

  double sales = 0, cost = 0, grams = 0;
  int cups = 0;

  for (final m in data) {
    final type = '${m['type'] ?? ''}';
    final price = (m['total_price'] is num)
        ? (m['total_price'] as num).toDouble()
        : _d(m['total_price']);
    final tcost = (m['total_cost'] is num)
        ? (m['total_cost'] as num).toDouble()
        : _d(m['total_cost']);

    sales += price;
    cost += tcost;

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

  double expensesSum = 0;
  for (final e in expensesList) {
    expensesSum += (e['amount'] is num)
        ? (e['amount'] as num).toDouble()
        : _d(e['amount']);
  }

  return Kpis(
    sales: sales,
    cost: cost,
    profit: sales - cost, // الربح التشغيلي (المصروفات حقل منفصل)
    cups: cups,
    grams: grams,
    expenses: expensesSum,
  );
});

/// ============ Drinks/Beans by name ============

final drinksByNameProvider = FutureProvider<List<GroupRow>>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
  final map = <String, GroupRow>{};

  for (final m in data) {
    if ('${m['type'] ?? ''}' != 'drink') continue;

    final name = ('${m['drink_name'] ?? m['name'] ?? 'مشروب'}').trim();
    final variant = ('${m['variant'] ?? m['roast'] ?? ''}').trim();
    final key = variant.isEmpty ? name : '$name - $variant';

    final price =
        (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
    final cost = (m['total_cost'] as num?)?.toDouble() ?? _d(m['total_cost']);
    final qRaw = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
    final cups = (qRaw > 0 ? qRaw.round() : 1);

    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(s: price, c: cost, p: price - cost, cu: cups);
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
});

/// يفكّك "توليفة العميل" ويجمع كل مكوّن باسمُه (name - variant) بالجرامات والسعر/التكلفة.
/// بنستخدم الحقول:
/// - components / items / lines (أيهم موجود)
/// - لكل مكوّن: name/variant/grams/line_total_price/line_total_cost
/// - لو line_total_price مفقود: بنوزّع beansAmount على المكونات بنِسَب الجرامات.
final beansByNameProvider = FutureProvider<List<GroupRow>>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);
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
    final type = '${m['type'] ?? ''}';

    // الأصناف/التوليفات العادية (ليست توليفة عميل)
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

    // توليفة العميل: نفكّك المكوّنات
    if (type == 'custom_blend') {
      final comps = asListMap(m['components']);
      final items = asListMap(m['items']);
      final lines = asListMap(m['lines']);
      final rowsRaw = comps.isNotEmpty
          ? comps
          : (items.isNotEmpty ? items : lines);

      if (rowsRaw.isEmpty) {
        // fallback: لو مفيش تفاصيل، حطها تحت "مخصص"
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

        // السعر/التكلفة لكل مكوّن:
        // لو موجود line_total_price/line_total_cost نستخدمهم.
        // لو مش موجود السعر: نوزّع beansAmount بنسبة الجرامات.
        double linePrice = r['line_total_price'] as double;
        double lineCost = r['line_total_cost'] as double;

        if (linePrice <= 0 && beansAmount > 0 && totalGrams > 0) {
          linePrice = beansAmount * (grams / totalGrams);
        }
        // لو مفيش cost على مستوى المكوّن هنسيبه 0 (غالبًا total_cost متوزّع أصلاً على السطور)

        addToMap(key: key, grams: grams, sales: linePrice, cost: lineCost);
      }

      continue;
    }

    // أي حاجات تانية مش مشروبات: نتجاهلها هنا
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
});

/// ============ Trends (3 خطوط: إجمالي + مشروبات + بن) ============

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

final statsTrendsProvider = FutureProvider<TrendsBundle>((ref) async {
  final data = await ref.watch(statsSalesProvider.future);

  final Map<DateTime, double> salesM = {};
  final Map<DateTime, double> profitM = {};
  final Map<DateTime, double> drinksSalesM = {};
  final Map<DateTime, double> drinksProfitM = {};
  final Map<DateTime, double> beansSalesM = {};
  final Map<DateTime, double> beansProfitM = {};

  for (final m in data) {
    final ts = _asUtc(m['created_at']);
    final k = opDayKeyUtc(ts); // 4ص تشغيلية
    final type = '${m['type'] ?? ''}';

    final price =
        (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
    final cost = (m['total_cost'] as num?)?.toDouble() ?? _d(m['total_cost']);
    final profit = price - cost;

    salesM[k] = (salesM[k] ?? 0) + price;
    profitM[k] = (profitM[k] ?? 0) + profit;

    if (type == 'drink') {
      drinksSalesM[k] = (drinksSalesM[k] ?? 0) + price;
      drinksProfitM[k] = (drinksProfitM[k] ?? 0) + profit;
    } else {
      // single/ready_blend/custom_blend → بن
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
});
