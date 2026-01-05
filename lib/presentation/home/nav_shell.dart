import 'package:elfouad_admin/presentation/forecast/pages/beans_forecast_page.dart';
import 'package:elfouad_admin/presentation/home/home_dashboard_page.dart';
import 'package:elfouad_admin/presentation/recipes/pages/recipes_list_page.dart';
import 'package:elfouad_admin/presentation/stocktake/pages/stocktake_page.dart';
import 'package:elfouad_admin/presentation/archive/pages/trash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'nav_state.dart';

// ???? ????????? ??? ????????
class NavShell extends StatefulWidget {
  const NavShell({super.key});

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavCubit, AppTab>(
      builder: (context, tab) {
        Widget screenFor(AppTab t) {
          switch (t) {
            case AppTab.home:
              return const HomeDashboardPage();
            case AppTab.history:
              return const HistoryScreen(); // ????
            case AppTab.stats:
              return const StatsScreen(); // ????????
            case AppTab.inventory:
              return const InventoryScreen(); // ?????
            case AppTab.stocktake:
              return const StocktakePage(); // ?????
            case AppTab.edits:
              return const EditsScreen(); // ???????
            case AppTab.expenses:
              return const ExpensesScreen(); // ???????
            case AppTab.recycleBin:
              return const TrashPage();

            case AppTab.recipes:
              return const RecipesListPage(); // ???????
            case AppTab.forecast:
              return const BeansForecastPage(); // ???????
          }
        }

        return Scaffold(body: screenFor(tab));
      },
    );
  }
}

/// ????? ????? (?????? ???????)
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(_) => const SizedBox();
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(_) => const SizedBox();
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(_) => const SizedBox();
}

class EditsScreen extends StatelessWidget {
  const EditsScreen({super.key});
  @override
  Widget build(_) => const SizedBox();
}

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});
  @override
  Widget build(_) => const SizedBox();
}

class GrindPage extends StatelessWidget {
  const GrindPage({super.key});
  @override
  Widget build(_) => const SizedBox();
}

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});
  @override
  Widget build(_) => const SizedBox();
}
