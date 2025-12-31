import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/presentation/Expenses/pages/expenses_page.dart';
import 'package:elfouad_admin/presentation/forecast/pages/beans_forecast_page.dart';
import 'package:elfouad_admin/presentation/grind/grind_page.dart';
import 'package:elfouad_admin/presentation/home/drawer_menu.dart';
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
  final AwesomeDrawerBarController _drawerController =
      AwesomeDrawerBarController();

  @override
  Widget build(BuildContext context) {
    // Keep as-is for compatibility; not used in lazy build (no design change).
    final screens = const <Widget>[
      SalesHistoryPage(),
      StatsPage(),
      InventoryPage(),
      ManagePage(),
      ExpensesPage(),
      GrindPage(),
      RecipesListPage(),
      BeansForecastPage(),
    ];

    return BlocBuilder<NavCubit, AppTab>(
      builder: (context, tab) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AwesomeDrawerBar(
            controller: _drawerController,
            menuScreen: const SideMenu(), // ???????
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
      },
    );
  }
}

/// ??????:
/// - ??????? AppTab (??????? ????) ?????? ????? NavTab.
/// - ????? ?????? ??????? ??? ??? ???? ???????? ????? ??????.
/// - IndexedStack ????? ??? ???? ?? ???? ??? ?? ????? ???.
class _MainStack extends StatefulWidget {
  final AppTab current; // ? ?????? Enum ??????? ??????
  const _MainStack({required this.current, required this.screens});

  // ????? ??????? ???? ?? ??????? ?? ?????? ?????? (?? ????? ??????).
  final List<Widget> screens;

  @override
  State<_MainStack> createState() => _MainStackState();
}

class _MainStackState extends State<_MainStack> {
  // ?????? ?? ???? ??? ??? ????? ???
  late final List<Widget?> _tabs = List<Widget?>.filled(
    8,
    null,
    growable: false,
  );

  Widget _buildRealPage(int i) {
    switch (i) {
      case 0:
        return const SalesHistoryPage();
      case 1:
        return const StatsPage();
      case 2:
        return const InventoryPage();
      case 3:
        return const ManagePage();
      case 4:
        return const ExpensesPage();
      case 5:
        return const GrindPage();
      case 6:
        return const RecipesListPage();
      case 7:
        return const BeansForecastPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.current.index;

    // ???? ?????? ??????? ??? ??? ???
    _tabs[index] ??= _buildRealPage(index);

    // ???? ??????? Placeholder ??? ??? ?????
    final children = List<Widget>.generate(_tabs.length, (i) {
      return _tabs[i] ?? const SizedBox.shrink();
    });

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: IndexedStack(index: index, children: children),
    );
  }
}
