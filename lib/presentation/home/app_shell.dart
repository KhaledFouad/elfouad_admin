import 'package:elfouad_admin/presentation/Expenses/pages/expenses_page.dart';
import 'package:elfouad_admin/presentation/forecast/pages/beans_forecast_page.dart';
import 'package:elfouad_admin/presentation/home/home_dashboard_page.dart';
import 'package:elfouad_admin/presentation/manage/pages/products_manage_page.dart';
import 'package:elfouad_admin/presentation/recipes/pages/recipes_list_page.dart'
    show RecipesListPage;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'nav_state.dart';
import 'package:elfouad_admin/presentation/History/pages/sales_history_page.dart';
import '../../presentation/inventory/pages/inventory_page.dart';
import '../../presentation/stats/pages/stats_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    // Keep as-is for compatibility; not used in lazy build (no design change).
    final screens = const <Widget>[
      HomeDashboardPage(),
      SalesHistoryPage(),
      StatsPage(),
      InventoryPage(),
      ManagePage(),
      ExpensesPage(),
      // GrindPage(),
      RecipesListPage(),
      BeansForecastPage(),
    ];

    return BlocBuilder<NavCubit, AppTab>(
      builder: (context, tab) {
        return WillPopScope(
          onWillPop: () async {
            if (tab != AppTab.home) {
              context.read<NavCubit>().setTab(AppTab.home);
              return false;
            }
            return true;
          },
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: _MainStack(current: tab, screens: screens),
          ),
        );
      },
    );
  }
}

class _MainStack extends StatefulWidget {
  final AppTab current;
  const _MainStack({required this.current, required this.screens});

  final List<Widget> screens;

  @override
  State<_MainStack> createState() => _MainStackState();
}

class _MainStackState extends State<_MainStack> {
  late final List<Widget?> _tabs = List<Widget?>.filled(
    AppTab.values.length,
    null,
    growable: false,
  );

  Widget _buildRealPage(int i) {
    switch (i) {
      case 0:
        return const HomeDashboardPage();
      case 1:
        return const SalesHistoryPage();
      case 2:
        return const StatsPage();
      case 3:
        return const InventoryPage();
      case 4:
        return const ManagePage();
      case 5:
        return const ExpensesPage();
      // case 6:
      //   return const GrindPage();
      case 7:
        return const RecipesListPage();
      case 8:
        return const BeansForecastPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.current.index;

    _tabs[index] ??= _buildRealPage(index);

    final children = List<Widget>.generate(_tabs.length, (i) {
      return _tabs[i] ?? const SizedBox.shrink();
    });

    return IndexedStack(index: index, children: children);
  }
}
