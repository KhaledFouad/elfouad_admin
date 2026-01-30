import '../models/archive_month.dart';

class ArchiveMonthsState {
  final List<ArchiveMonth> months;
  final bool loading;
  final bool fromCache;
  final Object? error;
  final DateTime? lastUpdated;

  const ArchiveMonthsState({
    required this.months,
    required this.loading,
    required this.fromCache,
    required this.error,
    required this.lastUpdated,
  });

  factory ArchiveMonthsState.initial() => const ArchiveMonthsState(
        months: [],
        loading: true,
        fromCache: false,
        error: null,
        lastUpdated: null,
      );

  ArchiveMonthsState copyWith({
    List<ArchiveMonth>? months,
    bool? loading,
    bool? fromCache,
    Object? error,
    DateTime? lastUpdated,
  }) {
    return ArchiveMonthsState(
      months: months ?? this.months,
      loading: loading ?? this.loading,
      fromCache: fromCache ?? this.fromCache,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
