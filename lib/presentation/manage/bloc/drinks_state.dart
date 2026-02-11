import '../models/drink_row.dart';

class DrinksState {
  final List<DrinkRow> items;
  final bool loading;
  final Object? error;

  const DrinksState({
    required this.items,
    required this.loading,
    required this.error,
  });

  DrinksState copyWith({List<DrinkRow>? items, bool? loading, Object? error}) {
    return DrinksState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}
