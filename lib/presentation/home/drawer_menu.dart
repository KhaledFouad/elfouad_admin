import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'nav_state.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<NavCubit>().state;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF543824), Color(0xFFC49A6C)],
        ),
      ),
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            children: [
              const _Header(),

              const SizedBox(height: 12),
              _MenuItem(
                icon: Icons.dashboard_rounded,
                label: AppStrings.tabHome,
                selected: selected == AppTab.home,
                onTap: () => _go(context, AppTab.home),
              ),
              _MenuItem(
                icon: Icons.receipt_long,
                label: AppStrings.tabHistory,
                selected: selected == AppTab.history,
                onTap: () => _go(context, AppTab.history),
              ),
              _MenuItem(
                icon: Icons.stacked_line_chart,
                label: AppStrings.tabStats,
                selected: selected == AppTab.stats,
                onTap: () => _go(context, AppTab.stats),
              ),
              _MenuItem(
                icon: Icons.archive_rounded,
                label: AppStrings.tabArchive,
                selected: selected == AppTab.archive,
                onTap: () => _go(context, AppTab.archive),
              ),

              _MenuItem(
                icon: Icons.inventory_2_outlined,
                label: AppStrings.tabInventory,
                selected: selected == AppTab.inventory,
                onTap: () => _go(context, AppTab.inventory),
              ),
              _MenuItem(
                icon: Icons.edit_note_outlined,
                label: AppStrings.tabEdits,
                selected: selected == AppTab.edits,
                onTap: () => _go(context, AppTab.edits),
              ),
              _MenuItem(
                icon: Icons.edit_note_outlined,
                label: AppStrings.tabRecipes,
                selected: selected == AppTab.recipes,
                onTap: () => _go(context, AppTab.recipes),
              ),

              _MenuItem(
                icon: Icons.account_balance_wallet_outlined,
                label: AppStrings.tabExpenses,
                selected: selected == AppTab.expenses,
                onTap: () => _go(context, AppTab.expenses),
              ),
              _MenuItem(
                icon: Icons.delete_sweep_outlined,
                label: AppStrings.tabRecycleBin,
                selected: selected == AppTab.recycleBin,
                onTap: () => _go(context, AppTab.recycleBin),
              ),
              _MenuItem(
                icon: Icons.auto_graph_outlined,
                label: AppStrings.tabForecast,
                selected: selected == AppTab.forecast,
                onTap: () => _go(context, AppTab.forecast),
              ),

              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white),
                title: const Text(
                  AppStrings.drawerClose,
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => AwesomeDrawerBar.of(context)?.toggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, AppTab tab) {
    context.read<NavCubit>().setTab(tab);
    AwesomeDrawerBar.of(context)?.toggle(); // ???? ???????
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: const CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white24,
        child: Icon(Icons.coffee, color: Colors.white),
      ),
      title: const Text(
        AppStrings.drawerTitle,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white.withAlpha(38) : Colors.transparent;
    final fg = Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: bg,
        leading: Icon(icon, color: fg),
        title: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w900,
            fontSize: 25,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
