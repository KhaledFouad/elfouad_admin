import 'dart:async';

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
            previousLoading: true,
            error: null,
            previewError: null,
            previousError: null,
          ),
        ) {
    _loadMonth(state.month, state.period);
  }

  static const int _previousMonthsCount = 6;

  final Map<String, List<_ArchiveDay>> _monthCache = {};
  final Map<String, bool> _monthBreakdownCache = {};
  String? _activeMonthKey;
  Map<String, _ArchiveDay> _activeDaysByKey = {};
  int _previousRequestId = 0;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _todaySub;
  bool _hasPeriodBreakdown = true;

  Future<void> refresh() => _loadMonth(
        state.month,
        state.period,
        force: true,
      );

  Future<void> ensureCurrentMonth() async {
    final now = defaultStatsMonth();
    final current = state.month;
    if (current.year == now.year && current.month == now.month) return;
    await _loadMonth(now, state.period);
  }

  Future<void> setMonth(DateTime month) =>
      _loadMonth(DateTime(month.year, month.month, 1), state.period);

  Future<void> setPeriod(StatsPeriod period) async {
    final effective = _hasPeriodBreakdown ? period : StatsPeriod.fullMonth;
    emit(state.copyWith(period: effective, loading: true, error: null));
    await _computeOverview(effective, state.month);
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
      bool hasBreakdown;
      if (!force && _monthCache.containsKey(key)) {
        days = _monthCache[key] ?? const [];
        hasBreakdown = _monthBreakdownCache[key] ?? false;
      } else {
        final source = await _fetchArchiveMonthSource(
          month,
          cacheFirst: !force,
        );
        days = source.days;
        hasBreakdown = source.hasBreakdown;
        _monthCache[key] = days;
        _monthBreakdownCache[key] = hasBreakdown;
      }

      _hasPeriodBreakdown = hasBreakdown;
      final effectivePeriod = hasBreakdown ? period : StatsPeriod.fullMonth;

      _activeMonthKey = key;
      _activeDaysByKey = {
        for (final day in days) day.dayKey: day,
      };
      _startArchiveMonthListener(month);

      final preview = hasBreakdown
          ? _buildThirdsPreview(days, month)
          : _buildFlatPreview(days);
      emit(
        state.copyWith(
          period: effectivePeriod,
          preview: preview,
          previewLoading: false,
          previewError: null,
        ),
      );

      unawaited(_loadPreviousMonths(month, force: force));
      await _computeOverview(effectivePeriod, month);
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

  Future<void> _loadPreviousMonths(
    DateTime month, {
    bool force = false,
  }) async {
    final requestId = ++_previousRequestId;
    emit(
      state.copyWith(
        previousLoading: true,
        previousError: null,
      ),
    );
    try {
      final previous = <MonthlyKpi>[];
      for (var i = 1; i <= _previousMonthsCount; i++) {
        final target = DateTime(month.year, month.month - i, 1);
        Kpis? kpis = await _fetchMonthlyKpisFromArchiveMonths(
          target,
          cacheFirst: !force,
        );
        kpis ??= _zeroKpis();
        previous.add(MonthlyKpi(month: target, kpis: kpis));
      }

      if (requestId != _previousRequestId) return;
      emit(
        state.copyWith(
          previousMonths: previous,
          previousLoading: false,
          previousError: null,
        ),
      );
    } catch (e) {
      if (requestId != _previousRequestId) return;
      emit(
        state.copyWith(
          previousLoading: false,
          previousError: e,
        ),
      );
    }
  }

  Future<void> _computeOverview(
    StatsPeriod period,
    DateTime month,
  ) async {
    try {
      final days = _activeDaysByKey.values.toList();
      final overview = _buildOverviewFromDaily(days, month, period);
      emit(state.copyWith(overview: overview, loading: false, error: null));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e));
    }
  }

  void _startArchiveMonthListener(DateTime month) {
    _todaySub?.cancel();
    final docRef = FirebaseFirestore.instance
        .collection('archive_months')
        .doc(_monthDocId(month));

    _todaySub = docRef.snapshots().listen((snap) {
      if (_activeMonthKey != _cacheKey(month)) return;
      final data = snap.data();
      final source = _monthSourceFromDoc(month, data);
      if (source.days.isNotEmpty) {
        _hasPeriodBreakdown = source.hasBreakdown;
        _activeDaysByKey = {for (final day in source.days) day.dayKey: day};
        _monthBreakdownCache[_activeMonthKey ?? _cacheKey(month)] =
            source.hasBreakdown;
      }
      _monthCache[_activeMonthKey ?? _cacheKey(month)] =
          _activeDaysByKey.values.toList();
      unawaited(_refreshComputedFromActive());
    });
  }

  Future<void> _refreshComputedFromActive() async {
    final days = _activeDaysByKey.values.toList();
    final overview = _buildOverviewFromDaily(
      days,
      state.month,
      state.period,
    );
    final preview = _hasPeriodBreakdown
        ? _buildThirdsPreview(days, state.month)
        : _buildFlatPreview(days);
    emit(
      state.copyWith(
        overview: overview,
        preview: preview,
        loading: false,
        previewLoading: false,
        error: null,
        previewError: null,
      ),
    );
  }

  ThirdsPreview _buildThirdsPreview(
    List<_ArchiveDay> days,
    DateTime month,
  ) {
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

  ThirdsPreview _buildFlatPreview(List<_ArchiveDay> days) {
    final total = _sumKpisForRange(
      days,
      startUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endUtc: DateTime.utc(9999, 1, 1),
    );
    return ThirdsPreview(
      firstThird: total,
      secondThird: total,
      thirdThird: total,
      month: total,
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
    final drinks = <DayVal>[];
    final grams = <DayVal>[];

    final filtered = days.where((d) {
      return !d.startUtc.isBefore(startUtc) && d.startUtc.isBefore(endUtc);
    }).toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

    for (final day in filtered) {
      final localDay = day.dayLocal;
      final hasAny =
          day.sales != 0 || day.profit != 0 || day.cups != 0 || day.grams != 0;
      if (!hasAny) continue;
      totalSales.add(DayVal(localDay, day.sales));
      totalProfit.add(DayVal(localDay, day.profit));
      drinks.add(DayVal(localDay, day.cups.toDouble()));
      grams.add(DayVal(localDay, day.grams));
    }

    return TrendsBundle(
      totalSales: totalSales,
      totalProfit: totalProfit,
      drinksSales: drinks,
      drinksProfit: drinks,
      beansSales: grams,
      beansProfit: grams,
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
    final activeBeansDays =
        days.where((d) => d.grams > 0).map((d) => d.dayLocal).toSet().length;

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
      averageOrdersPerDay:
          activeSalesDays > 0 ? (totalOrders / activeSalesDays) : 0.0,
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

  Kpis _zeroKpis() => const Kpis(
        sales: 0,
        cost: 0,
        profit: 0,
        cups: 0,
        grams: 0,
        expenses: 0,
        units: 0,
      );

  Future<_MonthSource> _fetchArchiveMonthSource(
    DateTime month, {
    bool cacheFirst = false,
  }) async {
    final docId = _monthDocId(month);
    final docRef =
        FirebaseFirestore.instance.collection('archive_months').doc(docId);
    final snap = await _getDocSnapshot(docRef, cacheFirst: cacheFirst);
    if (!snap.exists) return const _MonthSource.empty();
    return _monthSourceFromDoc(month, snap.data());
  }

  _MonthSource _monthSourceFromDoc(
    DateTime month,
    Map<String, dynamic>? data,
  ) {
    final days = _decodeDaysFromMonthDoc(data);
    if (days.isNotEmpty) {
      return _MonthSource(days: days, hasBreakdown: true);
    }
    final summaryDay = _decodeSummaryDayFromMonthDoc(month, data);
    if (summaryDay == null) {
      return const _MonthSource.empty();
    }
    return _MonthSource(days: [summaryDay], hasBreakdown: false);
  }

  List<_ArchiveDay> _decodeDaysFromMonthDoc(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final rawDays = data['days'];
    if (rawDays is! List) return const [];
    return rawDays
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map(_ArchiveDay.fromMap)
        .whereType<_ArchiveDay>()
        .toList();
  }

  _ArchiveDay? _decodeSummaryDayFromMonthDoc(
    DateTime month,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final rawSummary =
        (data['summary'] is Map) ? data['summary'] as Map : data;
    final summary = rawSummary.cast<String, dynamic>();

    final hasAny = _num(summary['sales']) != 0 ||
        _num(summary['cost']) != 0 ||
        _num(summary['profit']) != 0 ||
        _num(summary['grams']) != 0 ||
        _int(summary['cups'] ?? summary['drinks']) != 0 ||
        _int(summary['units'] ?? summary['snacks']) != 0 ||
        _num(summary['expenses']) != 0 ||
        _int(summary['orders']) != 0;
    if (!hasAny) return null;

    final dayLocal = DateTime(month.year, month.month, 1, 4);
    final dayKey =
        '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    return _ArchiveDay(
      dayKey: dayKey,
      startUtc: dayLocal.toUtc(),
      dayLocal: dayLocal,
      sales: _num(summary['sales']),
      cost: _num(summary['cost']),
      profit: _num(summary['profit']),
      cups: _int(summary['cups'] ?? summary['drinks']),
      grams: _num(summary['grams']),
      units: _int(summary['units'] ?? summary['snacks']),
      expenses: _num(summary['expenses']),
      orders: _int(summary['orders']),
      drinksRows: _rowsFromRaw(data['drinks_rows']),
      beansRows: _rowsFromRaw(data['beans_rows']),
      turkishRows: _rowsFromRaw(data['turkish_rows'], turkish: true),
      extrasRows: _rowsFromRaw(data['extras_rows']),
    );
  }

  Future<Kpis?> _fetchMonthlyKpisFromArchiveMonths(
    DateTime month, {
    bool cacheFirst = false,
  }) async {
    final docId = _monthDocId(month);
    final docRef =
        FirebaseFirestore.instance.collection('archive_months').doc(docId);
    final doc = await _getDocSnapshot(docRef, cacheFirst: cacheFirst);
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    final rawSummary =
        (data['summary'] is Map) ? data['summary'] as Map : data;
    final summary = rawSummary.cast<String, dynamic>();

    return Kpis(
      sales: _num(summary['sales']),
      cost: _num(summary['cost']),
      profit: _num(summary['profit']),
      cups: _int(summary['cups'] ?? summary['drinks']),
      grams: _num(summary['grams']),
      expenses: _num(summary['expenses']),
      units: _int(summary['units'] ?? summary['snacks']),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getDocSnapshot(
    DocumentReference<Map<String, dynamic>> ref, {
    bool cacheFirst = false,
  }) async {
    if (!cacheFirst) return ref.get();
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } catch (_) {}
    return ref.get();
  }

  String _cacheKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

  String _monthDocId(DateTime month) {
    final m = month.month.toString().padLeft(2, '0');
    return '${month.year}-$m';
  }

  @override
  Future<void> close() {
    _todaySub?.cancel();
    return super.close();
  }
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
      drinksRows: _rowsFromRaw(data['drinks_rows']),
      beansRows: _rowsFromRaw(data['beans_rows']),
      turkishRows: _rowsFromRaw(data['turkish_rows'], turkish: true),
      extrasRows: _rowsFromRaw(data['extras_rows']),
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

List<GroupRow> _rowsFromRaw(
  dynamic raw, {
  bool turkish = false,
}) {
  if (raw is! List) return const [];
  final out = <GroupRow>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = item.cast<String, dynamic>();
    final key = (map['key'] ?? map['name'] ?? '').toString().trim();
    if (key.isEmpty) continue;
    final plain = _num(map['plainGrams'] ?? (turkish ? map['plainCups'] : 0));
    final spiced = _num(map['spicedGrams'] ?? (turkish ? map['spicedCups'] : 0));
    final cups =
        _int(map['cups']) + (_int(map['cups']) == 0 && turkish ? _int(plain + spiced) : 0);
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

class _MonthSource {
  final List<_ArchiveDay> days;
  final bool hasBreakdown;

  const _MonthSource({
    required this.days,
    required this.hasBreakdown,
  });

  const _MonthSource.empty()
      : days = const <_ArchiveDay>[],
        hasBreakdown = false;
}
