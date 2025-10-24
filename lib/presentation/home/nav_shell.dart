import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/presentation/home/drawer_menu.dart';
import 'package:elfouad_admin/presentation/recipes/recipes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nav_state.dart';

// بدّل المحتويات حسب تبويباتك
class NavShell extends ConsumerWidget {
  const NavShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.watch(drawerControllerProvider);
    final tab = ref.watch(navIndexProvider);

    Widget screenFor(AppTab t) {
      switch (t) {
        case AppTab.history:
          return const HistoryScreen(); // سجّل
        case AppTab.stats:
          return const StatsScreen(); // إحصائيات
        case AppTab.inventory:
          return const InventoryScreen(); // مخزون
        case AppTab.edits:
          return const EditsScreen(); // تعديلات
        case AppTab.expenses:
          return const ExpensesScreen(); // مصروفات
        case AppTab.grind:
          return const GrindPage(); // طحن
        case AppTab.recipes:
          return const RecipesPage(); // توليفات
      }
    }

    return AwesomeDrawerBar(
      controller: ctrl,
      menuScreen: SideMenu(), // 👈 القائمة
      mainScreen: Scaffold(
        // 👈 لازم Scaffold هنا
        body: screenFor(tab),
      ),
      // اختياري: ضبط سلوك الأنيميشن والعرض
      slideWidth: MediaQuery.sizeOf(context).width * 0.78,
      shadowColor: Colors.black54,
      backgroundColor: const Color(0xFF543824),
    );
  }
}

/// أمثلة شاشات (بدّلها بشاشاتك)
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
