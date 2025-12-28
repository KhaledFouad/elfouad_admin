import '../models/manage_tab.dart';

class ManageTabState {
  final ManageTab tab;

  const ManageTabState({required this.tab});

  ManageTabState copyWith({ManageTab? tab}) {
    return ManageTabState(tab: tab ?? this.tab);
  }
}
