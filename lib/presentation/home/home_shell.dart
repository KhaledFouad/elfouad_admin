import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import '../admin/dashboard/admin_dashboard_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _pages = const [
    AdminDashboardPage(), // مؤقتًا كصفحة أولى
    AdminDashboardPage(), // Placeholder لصفحات أخرى
    AdminDashboardPage(),
    AdminDashboardPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: _pages[_index]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: SalomonBottomBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            selectedItemColor: cs.primary,
            unselectedItemColor: cs.onSurfaceVariant,
            items: [
              SalomonBottomBarItem(
                icon: Icon(Icons.receipt_long),
                title: Text("السجل"),
              ),
              SalomonBottomBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                title: Text("المخزون"),
              ),
              SalomonBottomBarItem(
                icon: Icon(Icons.edit_note),
                title: Text("إضافة/تعديل"),
              ),
              SalomonBottomBarItem(
                icon: Icon(Icons.bar_chart_rounded),
                title: Text("الإحصائيات"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
