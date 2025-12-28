import '../models/recipe_list_item.dart';

class RecipesState {
  final List<RecipeListItem> items;
  final bool loading;
  final Object? error;

  const RecipesState({
    required this.items,
    required this.loading,
    required this.error,
  });

  RecipesState copyWith({
    List<RecipeListItem>? items,
    bool? loading,
    Object? error,
  }) {
    return RecipesState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}
