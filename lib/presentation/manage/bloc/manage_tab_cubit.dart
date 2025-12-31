import 'dart:async' show unawaited;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manage_tab.dart';
import 'manage_tab_state.dart';

class ManageTabCubit extends Cubit<ManageTabState> {
  ManageTabCubit() : super(const ManageTabState(tab: ManageTab.drinks));

  static const _prefsKey = 'manage_tab';

  Future<void> loadLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    final match = ManageTab.values.cast<ManageTab?>().firstWhere(
          (t) => t?.name == raw,
          orElse: () => null,
        );
    if (match != null && match != state.tab) {
      emit(state.copyWith(tab: match));
    }
  }

  void setTab(ManageTab tab) {
    emit(state.copyWith(tab: tab));
    unawaited(_saveTab(tab));
  }

  Future<void> _saveTab(ManageTab tab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, tab.name);
  }
}
