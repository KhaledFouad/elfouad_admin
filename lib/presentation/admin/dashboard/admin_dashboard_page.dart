import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/kpi_row.dart';
import 'widgets/drinks_breakdown_table.dart';
import 'widgets/beans_breakdown_table.dart';
import 'widgets/top_lists.dart';
import 'widgets/trends.dart';
import 'providers.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(salesBreakdownsProviderMonth);
    final s = ref.watch(salesTrendMonthProvider);
    final p = ref.watch(profitTrendMonthProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإحصائيات — الشهر الحالي (4ص→4ص)')),
        body: b.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e,st) => Center(child: Text('خطأ: $e')),
          data: (data) => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              KpiRow(data: data),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المشروبات حسب النوع', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DrinksBreakdownTable(list: data.drinks),
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
                      BeansBreakdownTable(list: data.beans),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TopLists(drinks: data.drinks, beans: data.beans),
              const SizedBox(height: 12),
              s.when(
                loading: ()=> const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
                error: (e,st)=> Text('خطأ الترند (مبيعات): $e'),
                data: (salesPts) => p.when(
                  loading: ()=> const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
                  error: (e2,st2)=> Text('خطأ الترند (ربح): $e2'),
                  data: (profitPts) => Trends(sales: salesPts, profit: profitPts),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}