import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum AppTab { history, stats, inventory, edits, expenses, grind }

final navIndexProvider = StateProvider<AppTab>((ref) => AppTab.history);

final drawerControllerProvider = Provider<AwesomeDrawerBarController>((ref) {
  final c = AwesomeDrawerBarController();
  // If AwesomeDrawerBarController has a close() or similar method, use it here:
  // ref.onDispose(c.close);
  // Otherwise, remove the disposal line if not needed.
  return c;
});

/// ✅ افتح/اقفل الدروار باستخدام الـ context (بدون ProviderListenable/Reader)
void toggleDrawerFromContext(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  final ctrl = container.read(drawerControllerProvider);
  ctrl.toggle?.call();
}
