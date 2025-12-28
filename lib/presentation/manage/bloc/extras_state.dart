import '../models/extra_row.dart';

class ExtrasState {
  final List<ExtraRow> items;
  final bool loading;
  final Object? error;

  const ExtrasState({
    required this.items,
    required this.loading,
    required this.error,
  });

  ExtrasState copyWith({
    List<ExtraRow>? items,
    bool? loading,
    Object? error,
  }) {
    return ExtrasState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}
