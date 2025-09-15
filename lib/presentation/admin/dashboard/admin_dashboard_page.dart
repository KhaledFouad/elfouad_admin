import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/kpi_row.dart';
import 'widgets/drinks_breakdown_table.dart';
import 'widgets/beans_breakdown_table.dart';
import 'widgets/top_lists.dart';
import 'widgets/trends.dart';
import 'controllers/sales_controller.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  DateTimeRange? _range;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day, 4);
    _range = DateTimeRange(start: startLocal, end: startLocal.add(const Duration(days: 1)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _range == null) return;
      ref.read(salesControllerProvider.notifier)
        .fetch(_range!.start.toUtc(), _range!.end.toUtc());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesControllerProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإحصائيات — المبيعات المتقدّمة'),
          actions: [
            IconButton(
              onPressed: () {
                if (_range != null) {
                  ref.read(salesControllerProvider.notifier)
                    .fetch(_range!.start.toUtc(), _range!.end.toUtc());
                }
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
                ? Center(child: Text('خطأ: ${state.error}'))
                : state.data == null
                  ? const Center(child: Text('لا توجد بيانات'))
                  : ListView(
                      children: [
                        KpiRow(data: state.data!),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('المشروبات حسب النوع', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DrinksBreakdownTable(list: state.data!.drinks),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('البن حسب العائلة/المنشأ', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                BeansBreakdownTable(list: state.data!.beans),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const TopLists(),
                        const SizedBox(height: 12),
                        const Trends(),
                      ],
                    ),
        ),
      ),
    );
  }
}