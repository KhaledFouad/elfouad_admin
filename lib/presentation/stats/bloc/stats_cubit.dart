import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/stats_models.dart';
import '../models/stats_period.dart';
import 'stats_state.dart';

class StatsCubit extends Cubit<StatsState> {
  StatsCubit()
    : super(
        StatsState(
          month: defaultStatsMonth(),
          period: defaultStatsPeriod(),
          overview: null,
          preview: null,
          previousMonths: const [],
          loading: true,
          previewLoading: true,
          previousLoading: false,
          error: null,
          previewError: null,
          previousError: null,
        ),
      ) {
    _loadMonth(state.month, state.period);
  }

  final Map<String, List<_ArchiveDay>> _monthCache = {};
  Map<String, _ArchiveDay> _activeDaysByKey = {};

  Future<void> refresh() {
    return _loadMonth(state.month, state.period, force: true);
  }

  Future<void> ensureCurrentMonth() async {
    final now = defaultStatsMonth();
    final current = state.month;
    if (current.year == now.year && current.month == now.month) return;
    await _loadMonth(now, state.period);
  }

  Future<void> setMonth(DateTime month) =>
      _loadMonth(DateTime(month.year, month.month, 1), state.period);

  Future<void> setPeriod(StatsPeriod period) async {
    emit(state.copyWith(period: period, loading: true, error: null));
    await _computeOverview(period, state.month);
  }

  Future<void> _loadMonth(
    DateTime month,
    StatsPeriod period, {
    bool force = false,
  }) async {
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
      final key = _cacheKey(month);
      List<_ArchiveDay> days;
      if (!force && _monthCache.containsKey(key)) {
        days = _monthCache[key] ?? const [];
      } else {
        final nowMonth = defaultStatsMonth();
        final isCurrentMonth =
            month.year == nowMonth.year && month.month == nowMonth.month;
        days = await _fetchArchiveDailyForMonth(
          month,
          cacheFirst: !force && !isCurrentMonth,
        );
        _monthCache[key] = days;
      }

      _activeDaysByKey = {for (final day in days) day.dayKey: day};

      final preview = _buildThirdsPreview(days, month);
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
          previousLoading: false,
          previousError: e,
        ),
      );
    }
  }

  Future<void> _computeOverview(StatsPeriod period, DateTime month) async {
    try {
      final days = _activeDaysByKey.values.toList();
      final overview = _buildOverviewFromDaily(days, month, period);
      emit(state.copyWith(overview: overview, loading: false, error: null));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e));
    }
  }

  ThirdsPreview _buildThirdsPreview(List<_ArchiveDay> days, DateTime month) {
    Kpis kpisForRange(DateTime start, DateTime end) {
      return _sumKpisForRange(days, startUtc: start, endUtc: end);
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

  StatsOverview _buildOverviewFromDaily(
    List<_ArchiveDay> days,
    DateTime month,
    StatsPeriod period,
  ) {
    final range = statsComputeRange(month, period);
    final kpis = _sumKpisForRange(
      days,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    );
    return StatsOverview(
      kpis: kpis,
      drinks: _sumRowsForRange(
        days,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
        pickRows: (d) => d.drinksRows,
      ),
      beans: _sumRowsForRange(
        days,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
        pickRows: (d) => d.beansRows,
      ),
      turkish: _sumRowsForRange(
        days,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
        pickRows: (d) => d.turkishRows,
      ),
      extras: _sumRowsForRange(
        days,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
        pickRows: (d) => d.extrasRows,
      ),
      trends: _buildTrendsFromDaily(
        days,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      ),
      highlights: _buildHighlightsFromDaily(
        days,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      ),
    );
  }

  TrendsBundle _buildTrendsFromDaily(
    List<_ArchiveDay> days, {
    required DateTime startUtc,
    required DateTime endUtc,
  }) {
    final totalSales = <DayVal>[];
    final totalProfit = <DayVal>[];
    final beansGrams = <DayVal>[];
    final beansSales = <DayVal>[];
    final beansProfit = <DayVal>[];
    final turkishCups = <DayVal>[];
    final turkishSales = <DayVal>[];
    final turkishProfit = <DayVal>[];

    final filtered = days.where((d) {
      return !d.startUtc.isBefore(startUtc) && d.startUtc.isBefore(endUtc);
    }).toList()..sort((a, b) => a.startUtc.compareTo(b.startUtc));

    for (final day in filtered) {
      final localDay = day.dayLocal;
      final hasAny =
          day.sales != 0 || day.profit != 0 || day.cups != 0 || day.grams != 0;
      if (!hasAny) continue;

      double beansSalesValue = 0;
      double beansProfitValue = 0;
      for (final row in day.beansRows) {
        beansSalesValue += row.sales;
        beansProfitValue += row.profit;
      }

      int turkishCupsValue = 0;
      double turkishSalesValue = 0;
      double turkishProfitValue = 0;
      for (final row in day.turkishRows) {
        final cups = row.cups > 0
            ? row.cups
            : (row.plainGrams + row.spicedGrams).round();
        turkishCupsValue += cups;
        turkishSalesValue += row.sales;
        turkishProfitValue += row.profit;
      }

      totalSales.add(DayVal(localDay, day.sales));
      totalProfit.add(DayVal(localDay, day.profit));
      if (day.grams != 0 || beansSalesValue != 0 || beansProfitValue != 0) {
        beansGrams.add(DayVal(localDay, day.grams));
        beansSales.add(DayVal(localDay, beansSalesValue));
        beansProfit.add(DayVal(localDay, beansProfitValue));
      }
      if (turkishCupsValue != 0 ||
          turkishSalesValue != 0 ||
          turkishProfitValue != 0) {
        turkishCups.add(DayVal(localDay, turkishCupsValue.toDouble()));
        turkishSales.add(DayVal(localDay, turkishSalesValue));
        turkishProfit.add(DayVal(localDay, turkishProfitValue));
      }
    }

    return TrendsBundle(
      totalSales: totalSales,
      totalProfit: totalProfit,
      beansGrams: beansGrams,
      beansSales: beansSales,
      beansProfit: beansProfit,
      turkishCups: turkishCups,
      turkishSales: turkishSales,
      turkishProfit: turkishProfit,
    );
  }

  StatsHighlights _buildHighlightsFromDaily(
    List<_ArchiveDay> days, {
    required DateTime startUtc,
    required DateTime endUtc,
  }) {
    final salesByDay = <DateTime, double>{};
    final profitByDay = <DateTime, double>{};
    final servingsByDay = <DateTime, int>{};
    final ordersByDay = <DateTime, int>{};

    double totalSales = 0;
    int totalCups = 0;
    int totalUnits = 0;
    double totalBeansGrams = 0;
    int totalOrders = 0;

    for (final day in days) {
      if (day.startUtc.isBefore(startUtc) || !day.startUtc.isBefore(endUtc)) {
        continue;
      }
      final key = day.dayLocal;
      if (day.sales != 0) {
        salesByDay[key] = (salesByDay[key] ?? 0) + day.sales;
        totalSales += day.sales;
      }
      if (day.profit != 0) {
        profitByDay[key] = (profitByDay[key] ?? 0) + day.profit;
      }
      final servings = day.cups + day.units;
      if (servings > 0) {
        servingsByDay[key] = (servingsByDay[key] ?? 0) + servings;
      }
      if (day.orders > 0) {
        ordersByDay[key] = (ordersByDay[key] ?? 0) + day.orders;
        totalOrders += day.orders;
      }
      totalCups += day.cups;
      totalUnits += day.units;
      totalBeansGrams += day.grams;
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
      required Map<DateTime, int> byOrders,
    }) {
      if (day == null) return null;
      return DayHighlight(
        day: day,
        sales: bySales[day] ?? 0,
        profit: byProfit[day] ?? 0,
        servings: byServings[day] ?? 0,
        orders: byOrders[day] ?? 0,
      );
    }

    final activeSalesDays = salesByDay.keys.length;
    final activeProdDays = servingsByDay.keys.length;
    final activeBeansDays = days
        .where(
          (d) =>
              !d.startUtc.isBefore(startUtc) &&
              d.startUtc.isBefore(endUtc) &&
              d.grams > 0,
        )
        .map((d) => d.dayLocal)
        .toSet()
        .length;

    final avgDailySales = activeSalesDays > 0
        ? (totalSales / activeSalesDays)
        : 0.0;
    final avgDrinksPerDay = activeProdDays > 0
        ? (totalCups / activeProdDays)
        : 0.0;
    final avgSnacksPerDay = activeProdDays > 0
        ? (totalUnits / activeProdDays)
        : 0.0;
    final avgBeansGramsPerDay = activeBeansDays > 0
        ? (totalBeansGrams / activeBeansDays)
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
      averageBeansGramsPerDay: avgBeansGramsPerDay,
      averageOrdersPerDay: activeSalesDays > 0
          ? (totalOrders / activeSalesDays)
          : 0.0,
      totalOrders: totalOrders,
      activeDays: activeSalesDays,
    );
  }

  List<GroupRow> _sumRowsForRange(
    List<_ArchiveDay> days, {
    required DateTime startUtc,
    required DateTime endUtc,
    required List<GroupRow> Function(_ArchiveDay day) pickRows,
  }) {
    final byKey = <String, GroupRow>{};
    for (final day in days) {
      if (day.startUtc.isBefore(startUtc) || !day.startUtc.isBefore(endUtc)) {
        continue;
      }
      for (final row in pickRows(day)) {
        final prev = byKey[row.key];
        byKey[row.key] = (prev ?? GroupRow(key: row.key)).add(
          s: row.sales,
          c: row.cost,
          p: row.profit,
          g: row.grams,
          gPlain: row.plainGrams,
          gSpiced: row.spicedGrams,
          cu: row.cups,
        );
      }
    }
    final list = byKey.values.toList();
    list.sort((a, b) {
      final bySales = b.sales.compareTo(a.sales);
      if (bySales != 0) return bySales;
      return b.cups.compareTo(a.cups);
    });
    return list;
  }

  Kpis _sumKpisForRange(
    List<_ArchiveDay> days, {
    required DateTime startUtc,
    required DateTime endUtc,
  }) {
    double sales = 0, cost = 0, profit = 0, grams = 0, expenses = 0;
    int cups = 0, units = 0;

    for (final day in days) {
      if (day.startUtc.isBefore(startUtc) || !day.startUtc.isBefore(endUtc)) {
        continue;
      }
      sales += day.sales;
      cost += day.cost;
      profit += day.profit;
      grams += day.grams;
      expenses += day.expenses;
      cups += day.cups;
      units += day.units;
    }

    return Kpis(
      sales: sales,
      cost: cost,
      profit: profit,
      cups: cups,
      grams: grams,
      expenses: expenses,
      units: units,
    );
  }

  Future<List<_ArchiveDay>> _fetchArchiveDailyForMonth(
    DateTime month, {
    bool cacheFirst = false,
  }) async {
    final year = month.year.toString();
    final monthKey = month.month.toString().padLeft(2, '0');
    final query = FirebaseFirestore.instance
        .collection('archive_daily')
        .doc(year)
        .collection(monthKey);
    final snap = await _getQuerySnapshot(query, cacheFirst: cacheFirst);
    return snap.docs.map(_ArchiveDay.fromDoc).whereType<_ArchiveDay>().toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getQuerySnapshot(
    Query<Map<String, dynamic>> query, {
    bool cacheFirst = false,
  }) async {
    if (!cacheFirst) return query.get();
    try {
      final cached = await query.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) return cached;
    } catch (_) {}
    return query.get();
  }

  String _cacheKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
}

class _ArchiveDay {
  final String dayKey;
  final DateTime startUtc;
  final DateTime dayLocal;
  final double sales;
  final double cost;
  final double profit;
  final int cups;
  final double grams;
  final int units;
  final double expenses;
  final int orders;
  final List<GroupRow> drinksRows;
  final List<GroupRow> beansRows;
  final List<GroupRow> turkishRows;
  final List<GroupRow> extrasRows;

  const _ArchiveDay({
    required this.dayKey,
    required this.startUtc,
    required this.dayLocal,
    required this.sales,
    required this.cost,
    required this.profit,
    required this.cups,
    required this.grams,
    required this.units,
    required this.expenses,
    this.orders = 0,
    this.drinksRows = const [],
    this.beansRows = const [],
    this.turkishRows = const [],
    this.extrasRows = const [],
  });

  static _ArchiveDay? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return _ArchiveDay.fromMap(data, fallbackDayKey: doc.id);
  }

  static _ArchiveDay? fromMap(
    Map<String, dynamic> data, {
    String fallbackDayKey = '',
  }) {
    final key = (data['dayKey'] ?? fallbackDayKey).toString().trim();
    final parsed = _parseDayKey(key);
    if (parsed == null) return null;
    final dayLocal = DateTime(parsed.year, parsed.month, parsed.day, 4);

    DateTime startUtc = dayLocal.toUtc();
    final rawStart = data['startUtc'] ?? data['start_utc'];
    if (rawStart is String) {
      final dt = DateTime.tryParse(rawStart);
      if (dt != null) startUtc = dt.toUtc();
    } else if (rawStart is Timestamp) {
      startUtc = rawStart.toDate().toUtc();
    } else if (rawStart is DateTime) {
      startUtc = rawStart.toUtc();
    }

    return _ArchiveDay(
      dayKey: key,
      startUtc: startUtc,
      dayLocal: dayLocal,
      sales: _num(data['sales']),
      cost: _num(data['cost']),
      profit: _num(data['profit']),
      cups: _int(data['cups'] ?? data['drinks']),
      grams: _num(data['grams']),
      units: _int(data['units'] ?? data['snacks']),
      expenses: _num(data['expenses']),
      orders: _int(data['orders']),
      drinksRows: _rowsFromAny(data, const [
        'drinks_rows',
        'drinks_details_rows',
      ]),
      beansRows: _rowsFromRaw(data['beans_rows']),
      turkishRows: _rowsFromRaw(data['turkish_rows'], turkish: true),
      extrasRows: _rowsFromAny(data, const [
        'extras_rows',
        'extras_details_rows',
      ]),
    );
  }
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime? _parseDayKey(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (match == null) return null;
  final y = int.tryParse(match.group(1) ?? '');
  final m = int.tryParse(match.group(2) ?? '');
  final d = int.tryParse(match.group(3) ?? '');
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

List<GroupRow> _rowsFromRaw(dynamic raw, {bool turkish = false}) {
  if (raw is! List) return const [];
  final out = <GroupRow>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = item.cast<String, dynamic>();
    final key = (map['key'] ?? map['name'] ?? '').toString().trim();
    if (key.isEmpty) continue;
    final plain = _num(map['plainGrams'] ?? (turkish ? map['plainCups'] : 0));
    final spiced = _num(
      map['spicedGrams'] ?? (turkish ? map['spicedCups'] : 0),
    );
    final cups =
        _int(map['cups']) +
        (_int(map['cups']) == 0 && turkish ? _int(plain + spiced) : 0);
    out.add(
      GroupRow(
        key: key,
        sales: _num(map['sales']),
        cost: _num(map['cost']),
        profit: _num(map['profit']),
        grams: _num(map['grams']),
        plainGrams: plain,
        spicedGrams: spiced,
        cups: cups,
      ),
    );
  }
  return out;
}

List<GroupRow> _rowsFromAny(
  Map<String, dynamic> data,
  List<String> keys, {
  bool turkish = false,
}) {
  for (final key in keys) {
    if (!data.containsKey(key)) continue;
    final rows = _rowsFromRaw(data[key], turkish: turkish);
    if (rows.isNotEmpty) return rows;
  }
  return const [];
}
