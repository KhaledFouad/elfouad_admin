import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/manage_tab.dart';
import 'manage_tab_state.dart';

class ManageTabCubit extends Cubit<ManageTabState> {
  ManageTabCubit() : super(const ManageTabState(tab: ManageTab.all));

  void setTab(ManageTab tab) => emit(state.copyWith(tab: tab));
}
