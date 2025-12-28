import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/presentation/home/drawer_menu.dart';
import 'package:elfouad_admin/presentation/recipes/pages/recipes_list_page.dart';
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
  final AwesomeDrawerBarController _drawerController =
      AwesomeDrawerBarController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavCubit, AppTab>(
      builder: (context, tab) {
        Widget screenFor(AppTab t) {
          switch (t) {
            case AppTab.history:
              return const HistoryScreen(); // ????
            case AppTab.stats:
              return const StatsScreen(); // ????????
            case AppTab.inventory:
              return const InventoryScreen(); // ?????
            case AppTab.edits:
              return const EditsScreen(); // ???????
            case AppTab.expenses:
              return const ExpensesScreen(); // ???????
            case AppTab.grind:
              return const GrindPage(); // ???
            case AppTab.recipes:
              return const RecipesListPage(); // ???????
          }
        }

        return AwesomeDrawerBar(
          controller: _drawerController,
          menuScreen: const SideMenu(), // ?? ???????
          mainScreen: Scaffold(
            // ?? ???? Scaffold ???
            body: screenFor(tab),
          ),
          // ???????: ??? ???? ????????? ??????
          slideWidth: MediaQuery.sizeOf(context).width * 0.78,
          shadowColor: Colors.black54,
          backgroundColor: const Color(0xFF543824),
        );
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
