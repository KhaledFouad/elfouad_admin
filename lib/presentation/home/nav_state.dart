import 'package:flutter_bloc/flutter_bloc.dart';

enum AppTab {
  home,
  history,
  stats,
  archive,
  inventory,
  expenses,
  recycleBin,
  recipes,
}

class NavCubit extends Cubit<AppTab> {
  NavCubit() : super(AppTab.home);

  void setTab(AppTab tab) => emit(tab);
}
