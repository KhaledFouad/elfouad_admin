import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/presentation/stats/state/stats_period.dart';
import 'package:elfouad_admin/presentation/stats/widgets/drinks_by_type_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'state/stats_data_provider.dart';
import 'widgets/kpi_wrap.dart';
import 'widgets/period_chips.dart';
import 'widgets/triple_trend_chart.dart';
import 'widgets/beans_by_name_table.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});
  static const route = '/stats';

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  bool _profitMode = false;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(statsForMonthProvider);
    final period = ref.watch(statsSelectedPeriodProvider);

    final kpis = ref.watch(statsKpisProvider);
    final trends = ref.watch(statsTrendsProvider);
    final beans = ref.watch(beansByNameProvider);
    final drinks = ref.watch(drinksByNameProvider); // NEW

    return Scaffold(
      appBar: _brandedMonthAppBar(context, month),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
        children: [
          // الشيبس تحت البار
          PeriodChips(
            forMonth: month,
            selected: period,
            onSelected: (p) =>
                ref.read(statsSelectedPeriodProvider.notifier).state = p,
            onRangeChange: (_) {
              // لما الثلث يتغيّر—كل البروڤايدرز المبنية على statsSalesProvider هتتحدث تلقائي
              // (مش لازم invalidate، بس مفيش ضرر لو حابب تسيب السطر)
              // ref.invalidate(statsSalesProvider);
            },
          ),

          const SizedBox(height: 8),

          // KPIs مرنة
          kpis.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('تعذر تحميل الملخص: $e'),
            data: (v) => KpiWrap(
              items: [
                Kpi(
                  'إجمالي المبيعات',
                  v.sales.toStringAsFixed(2),
                  Icons.attach_money,
                ),
                Kpi('التكلفة', v.cost.toStringAsFixed(2), Icons.factory),
                Kpi('الربح', v.profit.toStringAsFixed(2), Icons.trending_up),
                Kpi('الأكواب', v.cups.toStringAsFixed(0), Icons.local_cafe),
                Kpi('جرامات البن', v.grams.toStringAsFixed(0), Icons.scale),
                Kpi(
                  'المصروفات',
                  v.expenses.toStringAsFixed(2),
                  Icons.account_balance_wallet,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // المشروبات حسب الاسم (NEW)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'المشروبات حسب الاسم',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  drinks.when(
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('تعذر تحميل بيانات المشروبات: $e'),
                    ),
                    data: (list) {
                      final rows = list
                          .map(
                            (x) => DrinkRow(
                              name: x.name,
                              cups: x.cups,
                              sales: x.sales,
                              cost: x.cost,
                              profit: x.profit,
                              avgPrice: x.cups > 0 ? (x.sales / x.cups) : 0,
                            ),
                          )
                          .toList();
                      return DrinksByNameTable(rows: rows);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // البن حسب الاسم
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'البن حسب الاسم',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  beans.when(
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('تعذر تحميل بيانات البن: $e'),
                    ),
                    data: (list) {
                      final rows = list
                          .map(
                            (x) => BeanRow(
                              name: x.name,
                              grams: x.grams,
                              sales: x.sales,
                              cost: x.cost,
                            ),
                          )
                          .toList();
                      return BeansByNameTable(rows: rows);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ترند ثلاثي: مبيعات/ربح (إجمالي + مشروبات + بن)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'الاتجاهات الزمنية (يومي)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('مبيعات'),
                          ),
                          ButtonSegment<bool>(value: true, label: Text('ربح')),
                        ],
                        selected: <bool>{_profitMode},
                        onSelectionChanged: (s) =>
                            setState(() => _profitMode = s.first),
                        style: const ButtonStyle(
                          visualDensity: VisualDensity(
                            horizontal: -2,
                            vertical: -2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  trends.when(
                    loading: () => const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('تعذر تحميل الترند: $e'),
                    data: (t) => TripleTrendChart(
                      line1: _profitMode ? t.totalProfit : t.totalSales,
                      lineDrinks: _profitMode ? t.drinksProfit : t.drinksSales,
                      lineBeansGrams: _profitMode
                          ? t.beansProfit
                          : t.beansSales,
                      asProfit: _profitMode,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _brandedMonthAppBar(
    BuildContext context,
    DateTime month,
  ) {
    final title = DateFormat('MMMM yyyy', 'ar').format(month);
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () =>
                AwesomeDrawerBar.of(context)?.toggle(), // ✅ التعديل هنا
          ),

          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'الشهر السابق',
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 32,
                ), // RTL: يمين=سابق
                onPressed: () {
                  final m = ref.read(statsForMonthProvider);
                  ref.read(statsForMonthProvider.notifier).state = DateTime(
                    m.year,
                    m.month - 1,
                    1,
                  );
                },
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.1,
              ), // توسيط العنوان
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.1),
              IconButton(
                tooltip: 'الشهر التالي',
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 32,
                ), // RTL: يسار=التالي
                onPressed: () {
                  final m = ref.read(statsForMonthProvider);
                  ref.read(statsForMonthProvider.notifier).state = DateTime(
                    m.year,
                    m.month + 1,
                    1,
                  );
                },
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 4,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5D4037), Color(0xFF795548)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
