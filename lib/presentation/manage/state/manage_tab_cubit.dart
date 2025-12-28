import 'package:flutter_bloc/flutter_bloc.dart';

enum ManageTab { all, drinks, singles, blends, extras }

class ManageTabCubit extends Cubit<ManageTab> {
  ManageTabCubit() : super(ManageTab.all);

  void setTab(ManageTab tab) => emit(tab);
}
