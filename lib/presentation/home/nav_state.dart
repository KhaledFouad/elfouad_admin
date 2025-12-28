import 'package:flutter_bloc/flutter_bloc.dart';

enum AppTab { history, stats, inventory, edits, expenses, grind, recipes }

class NavCubit extends Cubit<AppTab> {
  NavCubit() : super(AppTab.history);

  void setTab(AppTab tab) => emit(tab);
}
