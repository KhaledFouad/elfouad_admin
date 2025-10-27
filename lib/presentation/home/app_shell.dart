import 'package:elfouad_admin/presentation/expenses/expenses_page.dart';
import 'package:elfouad_admin/presentation/grind/grind_page.dart';
import 'package:elfouad_admin/presentation/home/drawer_menu.dart';
import 'package:elfouad_admin/presentation/manage/products_manage_page.dart';
import 'package:elfouad_admin/presentation/recipes/recipes_list_page.dart'
    show RecipesListPage;
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
    final tab = ref.watch(
      navIndexProvider,
    ); // AppTab enum (from nav_state.dart)

    // Keep as-is for compatibility; not used in lazy build (no design change).
    final screens = const <Widget>[
      SalesHistoryPage(),
      StatsPage(),
      InventoryPage(),
      ManagePage(),
      ExpensesPage(),
      GrindPage(),
      RecipesListPage(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AwesomeDrawerBar(
        controller: ctrl,
        menuScreen: SideMenu(), // القائمة
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

/// ملاحظة:
/// - بنستخدم AppTab (الموجود عندك) وخلصنا تضارب NavTab.
/// - بنبني الصفحة الحالية فقط أول مرة، ونكاشيها لباقي الجلسة.
/// - IndexedStack يحافظ على حالة كل تبّة بعد ما تتفتح مرة.
class _MainStack extends StatefulWidget {
  final AppTab current; // ✅ استخدم Enum المشروع الحالي
  const _MainStack({required this.current, required this.screens});

  // موجود للتماثل فقط، لا نستخدمه في البناء الكسول (لا تغيير ديزاين).
  final List<Widget> screens;

  @override
  State<_MainStack> createState() => _MainStackState();
}

class _MainStackState extends State<_MainStack> {
  // هنكاشي كل تبّة بعد أول زيارة لها
  late final List<Widget?> _tabs = List<Widget?>.filled(
    7,
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
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.current.index;

    // ابني التبّة الحالية فقط أول مرة
    _tabs[index] ??= _buildRealPage(index);

    // باقي التبّات Placeholder لحد أول زيارة
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
