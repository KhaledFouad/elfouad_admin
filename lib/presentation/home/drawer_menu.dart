import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nav_state.dart';

class SideMenu extends ConsumerWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(navIndexProvider);

    // خلفية متدرجة + Material فوقها عشان ListTile
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
                icon: Icons.receipt_long,
                label: 'السجل',
                selected: selected == AppTab.history,
                onTap: () => _go(context, ref, AppTab.history),
              ),
              _MenuItem(
                icon: Icons.stacked_line_chart,
                label: 'الإحصائيات',
                selected: selected == AppTab.stats,
                onTap: () => _go(context, ref, AppTab.stats),
              ),
              _MenuItem(
                icon: Icons.inventory_2_outlined,
                label: 'المخزون',
                selected: selected == AppTab.inventory,
                onTap: () => _go(context, ref, AppTab.inventory),
              ),
              _MenuItem(
                icon: Icons.edit_note_outlined,
                label: 'التعديلات',
                selected: selected == AppTab.edits,
                onTap: () => _go(context, ref, AppTab.edits),
              ),
              _MenuItem(
                icon: Icons.edit_note_outlined,
                label: 'تحضير التوليفات',
                selected: selected == AppTab.recipes,
                onTap: () => _go(context, ref, AppTab.recipes),
              ),
              _MenuItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'المصروفات',
                selected: selected == AppTab.expenses,
                onTap: () => _go(context, ref, AppTab.expenses),
              ),
              _MenuItem(
                icon: Icons.coffee_outlined,
                label: 'الطحن',
                selected: selected == AppTab.grind,
                onTap: () => _go(context, ref, AppTab.grind),
              ),

              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white),
                title: const Text(
                  'إغلاق',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => toggleDrawerFromContext(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, WidgetRef ref, AppTab tab) {
    ref.read(navIndexProvider.notifier).state = tab;
    toggleDrawerFromContext(context); // يقفل الدروار
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
        'لوحة إدارة بن الفؤاد',
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
    final bg = selected ? Colors.white.withOpacity(.15) : Colors.transparent;
    final fg = Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: bg,
        leading: Icon(icon, color: fg),
        title: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
        onTap: onTap,
      ),
    );
  }
}
