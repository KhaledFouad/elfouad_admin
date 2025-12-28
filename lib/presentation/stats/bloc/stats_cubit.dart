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
      _rawMonth = prepareStatsData(await fetchSalesRawForMonth(month));
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
      final data = filterStatsSales(
        _rawMonth,
        startUtc: range.startUtc,
        endUtc: range.endUtc,
      );
      final expenses = await fetchStatsExpenses(
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
}
