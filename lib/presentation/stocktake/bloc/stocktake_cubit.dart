import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/stocktake_models.dart';
import 'stocktake_state.dart';

class StocktakeCubit extends Cubit<StocktakeState> {
  StocktakeCubit() : super(const StocktakeState());

  void setMode(StocktakeMode mode) => emit(state.copyWith(mode: mode));

  void toggleMode() {
    final next = state.mode == StocktakeMode.record
        ? StocktakeMode.log
        : StocktakeMode.record;
    emit(state.copyWith(mode: next));
  }

  void setFilter(StocktakeFilter filter) =>
      emit(state.copyWith(filter: filter));

  void setOverwrite(bool overwrite) =>
      emit(state.copyWith(overwrite: overwrite));

  void setSearchQuery(String query) =>
      emit(state.copyWith(searchQuery: query.trim()));

  void setSaving(bool saving) => emit(state.copyWith(saving: saving));
}
