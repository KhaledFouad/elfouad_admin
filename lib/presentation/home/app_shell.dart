import 'package:elfouad_admin/presentation/Expenses/pages/expenses_page.dart';
import 'package:elfouad_admin/presentation/forecast/pages/beans_forecast_page.dart';
import 'package:elfouad_admin/presentation/home/home_dashboard_page.dart';
import 'package:elfouad_admin/presentation/manage/pages/products_manage_page.dart';
import 'package:elfouad_admin/presentation/recipes/pages/recipes_list_page.dart'
    show RecipesListPage;
import 'package:elfouad_admin/presentation/archive/pages/trash_page.dart';
import 'package:elfouad_admin/presentation/archive_months/pages/archive_months_page.dart';
import 'package:elfouad_admin/presentation/stocktake/pages/stocktake_page.dart';
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
      ArchiveMonthsPage(),
      InventoryPage(),
      ManagePage(),
      ExpensesPage(),
      // GrindPage(),
      TrashPage(),
      RecipesListPage(),
      BeansForecastPage(),
    ];

    return BlocBuilder<NavCubit, AppTab>(
      builder: (context, tab) {
        return PopScope(
          canPop: tab == AppTab.home,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (tab != AppTab.home) {
              context.read<NavCubit>().setTab(AppTab.home);
            }
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

  Widget _buildRealPage(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return const HomeDashboardPage();
      case AppTab.history:
        return const SalesHistoryPage();
      case AppTab.stats:
        return const StatsPage();
      case AppTab.archive:
        return const ArchiveMonthsPage();
      case AppTab.inventory:
        return const InventoryPage();
      case AppTab.stocktake:
        return const StocktakePage();
      case AppTab.edits:
        return const ManagePage();
      case AppTab.expenses:
        return const ExpensesPage();
      case AppTab.recycleBin:
        return const TrashPage();

      case AppTab.recipes:
        return const RecipesListPage();
      case AppTab.forecast:
        return const BeansForecastPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.current;
    final index = tab.index;

    _tabs[index] ??= _buildRealPage(tab);

    final children = List<Widget>.generate(_tabs.length, (i) {
      return _tabs[i] ?? const SizedBox.shrink();
    });

    return IndexedStack(index: index, children: children);
  }
}
