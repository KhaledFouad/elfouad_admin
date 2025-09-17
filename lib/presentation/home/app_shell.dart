import 'package:elfouad_admin/presentation/expenses/expenses_page.dart';
import 'package:elfouad_admin/presentation/home/drawer_menu.dart';
import 'package:elfouad_admin/presentation/manage/products_manage_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';

import 'nav_state.dart';
import '../../presentation/history/sales_history_page.dart';
import '../../presentation/stats/stats_page.dart';
import '../../presentation/inventory/inventory_page.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.watch(drawerControllerProvider);
    final tab = ref.watch(navIndexProvider);

    final screens = const <Widget>[
      SalesHistoryPage(),
      StatsPage(),
      InventoryPage(),
      ManagePage(),
      ExpensesPage(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AwesomeDrawerBar(
        controller: ctrl,
        menuScreen: SideMenu(), // القائمة,
        mainScreen: _MainStack(current: tab, screens: screens),
        angle: -10,
        backgroundColor: const Color(0xFFF0E7DC),
        showShadow: true,
        borderRadius: 24,
        slideWidth: MediaQuery.of(context).size.width * .72,
        openCurve: Curves.fastOutSlowIn,
        closeCurve: Curves.easeOutBack,
      ),
    );
  }
}

class _MainStack extends StatelessWidget {
  final AppTab current;
  final List<Widget> screens;
  const _MainStack({required this.current, required this.screens});

  @override
  Widget build(BuildContext context) {
    final index = current.index;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: IndexedStack(index: index, children: screens),
    );
  }
}
