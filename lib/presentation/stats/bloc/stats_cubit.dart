import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/stats_models.dart';
import '../models/stats_period.dart';
import '../utils/op_day.dart';
import '../utils/stats_data_provider.dart' as stats_data;
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
  final Map<String, List<Map<String, dynamic>>> _rawMonthCache = {};
  String? _activeMonthKey;
  Map<String, _ArchiveDay> _activeDaysByKey = {};
  int _previousRequestId = 0;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _todaySub;
  bool _useRawOverview = false;

  Future<void> refresh() => _loadMonth(
        state.month,
        state.period,
        force: true,
      );

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
        days = await _fetchArchiveDailyForMonth(
          month,
          cacheFirst: !force,
        );
        _monthCache[key] = days;
      }

      _activeMonthKey = key;
      _activeDaysByKey = {
        for (final day in days) day.dayKey: day,
      };
      _startTodayListenerIfNeeded(month);

      final rawMonth = await _fetchRawMonth(
        month,
        cacheFirst: !force,
      );
      final hasRaw = rawMonth.isNotEmpty;
      _useRawOverview = hasRaw;

      final preview = hasRaw
          ? _buildThirdsPreviewFromRaw(rawMonth, month)
          : _buildThirdsPreview(days, month);
      emit(
        state.copyWith(
          preview: preview,
          previewLoading: false,
          previewError: null,
        ),
      );

      unawaited(_loadPreviousMonths(month, force: force));
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
        if (kpis == null) {
          final key = _cacheKey(target);
          List<_ArchiveDay> days;
          if (!force && _monthCache.containsKey(key)) {
            days = _monthCache[key] ?? const [];
          } else {
            days = await _fetchArchiveDailyForMonth(
              target,
              cacheFirst: !force,
            );
            _monthCache[key] = days;
          }
          final range = statsComputeRange(target, StatsPeriod.fullMonth);
          kpis = _sumKpisForRange(
            days,
            startUtc: range.startUtc,
            endUtc: range.endUtc,
          );
        }
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

  Future<void> _computeOverview(StatsPeriod period, DateTime month) async {
    try {
      if (_useRawOverview) {
        final raw = _rawMonthCache[_cacheKey(month)] ??
            await _fetchRawMonth(month, cacheFirst: true);
        final overview = await _buildOverviewFromRaw(raw, month, period);
        emit(state.copyWith(overview: overview, loading: false, error: null));
        return;
      }

      final days = _activeDaysByKey.values.toList();
      final overview = _buildOverviewFromDaily(days, month, period);
      emit(state.copyWith(overview: overview, loading: false, error: null));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e));
    }
  }

  void _startTodayListenerIfNeeded(DateTime month) {
    _todaySub?.cancel();

    final now = DateTime.now();
    final dayKey = opDayKeyFromLocal(now);
    final parsed = _parseDayKey(dayKey);
    if (parsed == null) return;
    if (parsed.year != month.year || parsed.month != month.month) return;

    final year = parsed.year.toString();
    final monthKey = parsed.month.toString().padLeft(2, '0');
    final docRef = FirebaseFirestore.instance
        .collection('archive_daily')
        .doc(year)
        .collection(monthKey)
        .doc(dayKey);

    debugPrint('[STATS] subscribed to daily doc: $dayKey');

    _todaySub = docRef.snapshots().listen((snap) {
      if (_activeMonthKey != _cacheKey(month)) return;
      if (!snap.exists) {
        _activeDaysByKey.remove(dayKey);
      } else {
        final day = _ArchiveDay.fromDoc(snap);
        if (day != null) {
          _activeDaysByKey[day.dayKey] = day;
        }
      }
      _monthCache[_activeMonthKey ?? _cacheKey(month)] =
          _activeDaysByKey.values.toList();
      _refreshComputedFromActive();
    });
  }

  void _refreshComputedFromActive() {
    if (_useRawOverview) {
      return;
    }
    final days = _activeDaysByKey.values.toList();
    final overview = _buildOverviewFromDaily(
      days,
      state.month,
      state.period,
    );
    final preview = _buildThirdsPreview(days, state.month);
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

  Future<List<Map<String, dynamic>>> _fetchRawMonth(
    DateTime month, {
    bool cacheFirst = false,
  }) async {
    final key = _cacheKey(month);
    if (cacheFirst && _rawMonthCache.containsKey(key)) {
      return _rawMonthCache[key] ?? const <Map<String, dynamic>>[];
    }
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startLocal = DateTime(month.year, month.month, 1, 4);
    final endLocal = DateTime(
      month.year,
      month.month,
      daysInMonth,
      4,
    ).add(const Duration(days: 1));

    final raw = await stats_data.fetchSalesRawForRange(
      startLocal: startLocal,
      endLocal: endLocal,
      cacheFirst: cacheFirst,
    );
    _rawMonthCache[key] = raw;
    return raw;
  }

  ThirdsPreview _buildThirdsPreviewFromRaw(
    List<Map<String, dynamic>> raw,
    DateTime month,
  ) {
    final prepared = stats_data.prepareStatsData(raw);

    Kpis kpisForRange(DateTime start, DateTime end) {
      final filtered = stats_data.filterStatsSales(
        prepared,
        startUtc: start,
        endUtc: end,
      );
      return stats_data.buildKpis(
        filtered,
        const <Map<String, dynamic>>[],
        startUtc: start,
        endUtc: end,
      );
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

  Future<StatsOverview> _buildOverviewFromRaw(
    List<Map<String, dynamic>> raw,
    DateTime month,
    StatsPeriod period,
  ) async {
    final range = statsComputeRange(month, period);
    final prepared = stats_data.prepareStatsData(raw);
    final filtered = stats_data.filterStatsSales(
      prepared,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    );

    final rawExpenses = await stats_data.fetchStatsExpenses(
      startUtc: range.startUtc,
      endUtc: range.endUtc,
      cacheFirst: true,
    );
    final expenses = stats_data.filterStatsExpenses(
      rawExpenses,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    );

    final kpis = stats_data.buildKpis(
      filtered,
      expenses,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    );

    return StatsOverview(
      kpis: kpis,
      drinks: stats_data.buildDrinksRows(
        filtered,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      ),
      beans: stats_data.buildBeansRows(
        filtered,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      ),
      turkish: stats_data.buildTurkishRows(
        filtered,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      ),
      extras: stats_data.buildExtrasRows(
        filtered,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      ),
      trends: stats_data.buildTrends(
        filtered,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      ),
      highlights: stats_data.buildHighlights(
        filtered,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      ),
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
      drinks: const [],
      beans: const [],
      turkish: const [],
      extras: const [],
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

    double totalSales = 0;
    int totalCups = 0;
    int totalUnits = 0;
    double totalBeansGrams = 0;

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
    }) {
      if (day == null) return null;
      return DayHighlight(
        day: day,
        sales: bySales[day] ?? 0,
        profit: byProfit[day] ?? 0,
        servings: byServings[day] ?? 0,
        orders: 0,
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
      ),
      topProfitDay: highlightFor(
        maxDayByProfit,
        bySales: salesByDay,
        byProfit: profitByDay,
        byServings: servingsByDay,
      ),
      busiestDay: highlightFor(
        maxDayByServings,
        bySales: salesByDay,
        byProfit: profitByDay,
        byServings: servingsByDay,
      ),
      averageDailySales: avgDailySales,
      averageDrinksPerDay: avgDrinksPerDay,
      averageSnacksPerDay: avgSnacksPerDay,
      averageBeansGramsPerDay: avgBeansGramsPerDay,
      averageOrdersPerDay: 0.0,
      totalOrders: 0,
      activeDays: activeSalesDays,
    );
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
    return snap.docs
        .map(_ArchiveDay.fromDoc)
        .whereType<_ArchiveDay>()
        .toList();
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
  });

  static _ArchiveDay? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final key = (data['dayKey'] ?? doc.id).toString().trim();
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
  final match = RegExp(r'^(\\d{4})-(\\d{2})-(\\d{2})\$').firstMatch(trimmed);
  if (match == null) return null;
  final y = int.tryParse(match.group(1) ?? '');
  final m = int.tryParse(match.group(2) ?? '');
  final d = int.tryParse(match.group(3) ?? '');
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}
