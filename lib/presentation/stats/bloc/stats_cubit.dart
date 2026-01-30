import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/stats_models.dart';
import '../models/stats_period.dart';
import '../utils/stats_data_provider.dart';
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

  List<Map<String, dynamic>> _rawMonth = const [];
  List<Map<String, dynamic>> _rawExpenses = const [];
  final Map<String, List<Map<String, dynamic>>> _rawMonthCache = {};
  final Map<String, List<Map<String, dynamic>>> _rawExpensesCache = {};
  int _previousRequestId = 0;

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
      if (!force &&
          _rawMonthCache.containsKey(key) &&
          _rawExpensesCache.containsKey(key)) {
        _rawMonth = _rawMonthCache[key] ?? const [];
        _rawExpenses = _rawExpensesCache[key] ?? const [];
      } else {
        _rawMonth = prepareStatsData(
          await fetchSalesRawForMonth(month, cacheFirst: !force),
        );
        final fullRange = statsComputeRange(month, StatsPeriod.fullMonth);
        _rawExpenses = await fetchStatsExpenses(
          startUtc: fullRange.startUtc,
          endUtc: fullRange.endUtc,
          cacheFirst: !force,
        );
        _rawMonthCache[key] = _rawMonth;
        _rawExpensesCache[key] = _rawExpenses;
      }
      final preview = _buildThirdsPreview(_rawMonth, month);
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
        final key = _cacheKey(target);
        List<Map<String, dynamic>> raw;
        if (!force && _rawMonthCache.containsKey(key)) {
          raw = _rawMonthCache[key] ?? const [];
        } else {
          raw = prepareStatsData(
            await fetchSalesRawForMonth(target, cacheFirst: !force),
          );
          _rawMonthCache[key] = raw;
        }
        final range = statsComputeRange(target, StatsPeriod.fullMonth);
        final kpis = buildKpis(
          raw,
          const [],
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        );
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
      final range = statsComputeRange(month, period);
      final data = filterStatsSales(
        _rawMonth,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      );
      final expenses = filterStatsExpenses(
        _rawExpenses,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      );
      final overview = StatsOverview(
        kpis: buildKpis(
          data,
          expenses,
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        ),
        drinks: buildDrinksRows(
          data,
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        ),
        beans: buildBeansRows(
          data,
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        ),
        turkish: buildTurkishRows(
          data,
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        ),
        extras: buildExtrasRows(
          data,
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        ),
        trends: buildTrends(
          data,
          startUtc: range.startUtc,
          endUtc: range.endUtc,
        ),
        highlights: buildHighlights(
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
      return buildKpis(rawMonth, const [], startUtc: start, endUtc: end);
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

  String _cacheKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
}
