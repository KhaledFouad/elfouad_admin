import '../models/stats_models.dart';
import '../models/stats_period.dart';

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
