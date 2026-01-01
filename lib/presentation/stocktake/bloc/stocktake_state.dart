import 'package:elfouad_admin/presentation/stocktake/models/stocktake_models.dart';

class StocktakeState {
  final StocktakeMode mode;
  final StocktakeFilter filter;
  final bool overwrite;
  final String searchQuery;
  final bool saving;

  const StocktakeState({
    this.mode = StocktakeMode.record,
    this.filter = StocktakeFilter.all,
    this.overwrite = false,
    this.searchQuery = '',
    this.saving = false,
  });

  StocktakeState copyWith({
    StocktakeMode? mode,
    StocktakeFilter? filter,
    bool? overwrite,
    String? searchQuery,
    bool? saving,
  }) {
    return StocktakeState(
      mode: mode ?? this.mode,
      filter: filter ?? this.filter,
      overwrite: overwrite ?? this.overwrite,
      searchQuery: searchQuery ?? this.searchQuery,
      saving: saving ?? this.saving,
    );
  }
}
