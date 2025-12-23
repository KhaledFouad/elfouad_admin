import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/core/app_strings.dart';
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
import 'widgets/highlights_card.dart';

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
    final theme = Theme.of(context);

    final overview = ref.watch(statsOverviewProvider);
    return Scaffold(
      appBar: _brandedMonthAppBar(context, month),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          refreshStatsProviders(ref); // invalidate + re-fetch
          await Future.delayed(const Duration(milliseconds: 350));
        },
        child: ListView(
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
            overview.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) =>
                  Text(AppStrings.loadFailed(AppStrings.summaryLabel, e)),
              data: (bundle) {
                final v = bundle.kpis;
                return KpiWrap(
                  items: [
                    Kpi(
                      AppStrings.totalSalesLabel,
                      v.sales.toStringAsFixed(2),
                      Icons.attach_money,
                    ),
                    Kpi(
                      AppStrings.costLabelDefinite,
                      v.cost.toStringAsFixed(2),
                      Icons.factory,
                    ),
                    Kpi(
                      AppStrings.profitLabelDefinite,
                      v.profit.toStringAsFixed(2),
                      Icons.trending_up,
                    ),
                    Kpi(
                      AppStrings.cupsLabel,
                      v.cups.toStringAsFixed(0),
                      Icons.local_cafe,
                    ),
                    Kpi(
                      AppStrings.snacksLabel,
                      v.units.toStringAsFixed(0),
                      Icons.cookie_rounded,
                    ),
                    Kpi(
                      AppStrings.coffeeGramsLabel,
                      v.grams.toStringAsFixed(0),
                      Icons.scale,
                    ),
                    Kpi(
                      AppStrings.expensesTitle,
                      v.expenses.toStringAsFixed(2),
                      Icons.account_balance_wallet,
                    ),
                  ],
                );
              },
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
                        AppStrings.drinksAndSnacksTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    overview.when(
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          AppStrings.loadFailed(AppStrings.drinksDataLabel, e),
                        ),
                      ),
                      data: (bundle) {
                        final drinkRows = bundle.drinks
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
                        final snackRows = bundle.extras
                            .map(
                              (x) => DrinkRow(
                                name: x.name,
                                cups: x.cups,
                                sales: x.sales,
                                cost: x.cost,
                                profit: x.profit,
                                avgPrice:
                                    x.cups > 0 ? (x.sales / x.cups) : 0,
                              ),
                            )
                            .toList();
                        final combined = [...drinkRows, ...snackRows]
                          ..sort((a, b) => b.sales.compareTo(a.sales));
                        if (combined.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(AppStrings.noDataForRange),
                          );
                        }
                        return DrinksByNameTable(rows: combined);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // أبرز الأيام والمؤشرات
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
                        AppStrings.dailyHighlightsTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    overview.when(
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          AppStrings.loadFailed(
                            AppStrings.dailyHighlightsLabel,
                            e,
                          ),
                        ),
                      ),
                      data: (bundle) =>
                          StatsHighlightsCard(highlights: bundle.highlights),
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
                        AppStrings.beansByNameTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    overview.when(
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          AppStrings.loadFailed(AppStrings.beansDataLabel, e),
                        ),
                      ),
                      data: (bundle) {
                        final rows = bundle.beans
                            .map(
                              (x) => BeanRow(
                                name: x.name,
                                grams: x.grams,
                                plainGrams: x.plainGrams,
                                spicedGrams: x.spicedGrams,
                                sales: x.sales,
                                cost: x.cost,
                              ),
                            )
                            .toList();
                        if (rows.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(AppStrings.noDataForRange),
                          );
                        }
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
                          AppStrings.dailyTrendsTitle,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              label: Text(AppStrings.salesLabel),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text(AppStrings.profitLabel),
                            ),
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
                    overview.when(
                      loading: () => const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) =>
                          Text(AppStrings.loadFailed(AppStrings.trendLabel, e)),
                      data: (bundle) {
                        final t = bundle.trends;
                        return TripleTrendChart(
                          line1: _profitMode ? t.totalProfit : t.totalSales,
                          lineDrinks: _profitMode
                              ? t.drinksProfit
                              : t.drinksSales,
                          lineBeansGrams: _profitMode
                              ? t.beansProfit
                              : t.beansSales,
                          asProfit: _profitMode,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                tooltip: AppStrings.previousMonthTooltip,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 25,
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
                width: MediaQuery.of(context).size.width * 0.05,
              ), // توسيط العنوان
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.05),
              IconButton(
                tooltip: AppStrings.nextMonthTooltip,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 25,
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
