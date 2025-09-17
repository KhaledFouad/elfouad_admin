import 'package:elfouad_admin/presentation/stats/widgets/top_lists.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'utils/colors.dart';
import 'widgets/period_chips.dart';
import 'widgets/kpi_card.dart';
import 'widgets/section_card.dart';
import 'widgets/breakdown_table.dart';
import 'widgets/triple_trend_chart.dart';
import 'state/stats_data_provider.dart';
import 'state/expenses_provider.dart';
import 'state/sales_raw_provider.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});
  static const route = '/stats';
  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  bool _profitMode = false; // تبويب الجراف: مبيعات/ربح

  @override
  Widget build(BuildContext context) {
    final salesRaw = ref.watch(salesRawProvider);
    final kpis = ref.watch(kpisProvider);
    final expenses = ref.watch(expensesTotalProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              automaticallyImplyLeading: false,
              title: const Text(
                'الإحصائيات',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 6,
              backgroundColor: Colors.transparent,
              flexibleSpace: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kBrown, Color(0xFF8A6A4A)],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PeriodChips(
                    forMonth: DateTime.now(),
                    selected: StatsPeriod.month,
                    onRangeChange: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
        body: salesRaw.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('تعذر تحميل البيانات: $e')),
          data: (_) {
            final drinks = ref.watch(drinksByTypeProvider);
            final beans = ref.watch(beansByFamilyProvider);
            final trends = ref.watch(trends3Provider);

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                // KPIs — استخدم Wrap لتفادي overflow
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: _kpiW(context),
                      child: KpiWrap(
                        title: 'إجمالي المبيعات',
                        value: kpis.sales.toStringAsFixed(2),
                        icon: Icons.attach_money,
                      ),
                    ),
                    SizedBox(
                      width: _kpiW(context),
                      child: KpiCard(
                        title: 'التكلفة',
                        value: kpis.cost.toStringAsFixed(2),
                        icon: Icons.factory,
                      ),
                    ),
                    SizedBox(
                      width: _kpiW(context),
                      child: KpiCard(
                        title: 'الربح',
                        value: kpis.profit.toStringAsFixed(2),
                        icon: Icons.trending_up,
                      ),
                    ),
                    SizedBox(
                      width: _kpiW(context),
                      child: KpiCard(
                        title: 'الأكواب',
                        value: '${kpis.cups}',
                        icon: Icons.local_cafe,
                      ),
                    ),
                    SizedBox(
                      width: _kpiW(context),
                      child: KpiCard(
                        title: 'جرامات البن',
                        value: kpis.grams.toStringAsFixed(0),
                        icon: Icons.scale,
                      ),
                    ),
                    SizedBox(
                      width: _kpiW(context),
                      child: expenses.when(
                        loading: () => const KpiCard(
                          title: 'المصروفات',
                          value: '—',
                          icon: Icons.account_balance_wallet,
                        ),
                        error: (e, _) => KpiCard(
                          title: 'المصروفات',
                          value: '0',
                          icon: Icons.account_balance_wallet,
                        ),
                        data: (v) => KpiCard(
                          title: 'المصروفات',
                          value: v.toStringAsFixed(2),
                          icon: Icons.account_balance_wallet,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                SectionCard(
                  title: 'المشروبات حسب النوع',
                  child: BreakdownTable(rows: drinks, showCups: true),
                ),
                const SizedBox(height: 12),

                SectionCard(
                  title: 'البن حسب العائلة/المنشأ',
                  child: BreakdownTable(rows: beans, showGrams: true),
                ),
                const SizedBox(height: 12),

                Top5List(
                  titleLeft: 'Beans جرامات',
                  unitLeft: 'g',
                  titleRight: 'Beans ربح',
                  unitRight: 'profit',
                  leftRows: ref.watch(top5BeansByGramsProvider),
                  rightRows: ref.watch(top5BeansByProfitProvider),
                ),
                const SizedBox(height: 12),

                Top5List(
                  titleLeft: 'Drinks أكواب',
                  unitLeft: 'cups',
                  titleRight: 'Drinks ربح',
                  unitRight: 'profit',
                  leftRows: ref.watch(top5DrinksByCupsProvider),
                  rightRows: ref.watch(top5DrinksByProfitProvider),
                ),
                const SizedBox(height: 12),

                // تبويب بسيط بين مبيعات/ربح للجراف
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('مبيعات'),
                      selected: !_profitMode,
                      onSelected: (_) => setState(() => _profitMode = false),
                      selectedColor: kBrown,
                      labelStyle: TextStyle(
                        color: !_profitMode ? Colors.white : kBrown,
                      ),
                      backgroundColor: kBeigeSoft(.35),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ربح'),
                      selected: _profitMode,
                      onSelected: (_) => setState(() => _profitMode = true),
                      selectedColor: kBrown,
                      labelStyle: TextStyle(
                        color: _profitMode ? Colors.white : kBrown,
                      ),
                      backgroundColor: kBeigeSoft(.35),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                SectionCard(
                  title: 'الاتجاهات الزمنية (يومي)',
                  child: TripleTrendChart(
                    line1: _profitMode ? trends.totalProfit : trends.totalSales,
                    lineDrinks: trends.drinksSales,
                    lineBeansGrams: trends.beansGrams,
                    asProfit: _profitMode,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _kpiW(BuildContext ctx) {
    // عمودين على الموبايل
    final w = MediaQuery.of(ctx).size.width;
    return (w - 12 * 1 - 12 * 1) / 2; // تقريبًا عرض نصف مع المسافات
  }
}
