import '../models/stats_models.dart';
import '../models/stats_period.dart';

class StatsState {
  final DateTime month;
  final StatsPeriod period;
  final StatsOverview? overview;
  final ThirdsPreview? preview;
  final List<MonthlyKpi> previousMonths;
  final bool loading;
  final bool previewLoading;
  final bool previousLoading;
  final Object? error;
  final Object? previewError;
  final Object? previousError;

  const StatsState({
    required this.month,
    required this.period,
    required this.overview,
    required this.preview,
    required this.previousMonths,
    required this.loading,
    required this.previewLoading,
    required this.previousLoading,
    required this.error,
    required this.previewError,
    required this.previousError,
  });

  StatsState copyWith({
    DateTime? month,
    StatsPeriod? period,
    StatsOverview? overview,
    ThirdsPreview? preview,
    List<MonthlyKpi>? previousMonths,
    bool? loading,
    bool? previewLoading,
    bool? previousLoading,
    Object? error,
    Object? previewError,
    Object? previousError,
  }) {
    return StatsState(
      month: month ?? this.month,
      period: period ?? this.period,
      overview: overview ?? this.overview,
      preview: preview ?? this.preview,
      previousMonths: previousMonths ?? this.previousMonths,
      loading: loading ?? this.loading,
      previewLoading: previewLoading ?? this.previewLoading,
      previousLoading: previousLoading ?? this.previousLoading,
      error: error,
      previewError: previewError,
      previousError: previousError,
    );
  }
}
