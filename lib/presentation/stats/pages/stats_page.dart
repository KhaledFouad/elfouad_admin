import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:elfouad_admin/presentation/stats/bloc/stats_cubit.dart';
import 'package:elfouad_admin/presentation/stats/widgets/beans_by_name_table.dart';
import 'package:elfouad_admin/presentation/stats/widgets/drinks_by_type_table.dart';
import 'package:elfouad_admin/presentation/stats/widgets/highlights_card.dart';
import 'package:elfouad_admin/presentation/stats/widgets/kpi_wrap.dart';
import 'package:elfouad_admin/presentation/stats/widgets/period_chips.dart';
import 'package:elfouad_admin/presentation/stats/widgets/turkish_coffee_table.dart';
import 'package:elfouad_admin/presentation/stats/widgets/triple_trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  static const route = '/stats';

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _syncedMonth = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[STATS] using archive_daily breakdown for stats');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedMonth) return;
    _syncedMonth = true;
    context.read<StatsCubit>().ensureCurrentMonth();
  }

  bool _isTurkishName(String name) {
    final n = name.toLowerCase();
    return n.contains('تركي') || n.contains('تركى') || n.contains('turk');
  }

  String _baseName(String name) {
    final idx = name.indexOf(' - ');
    if (idx <= 0) return name;
    return name.substring(0, idx);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StatsCubit>().state;
    final month = state.month;
    final period = state.period;
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final maxWidth = breakpoints.largerThan(TABLET) ? 1000.0 : double.infinity;
    final horizontalPadding = isPhone ? 12.0 : 20.0;

    return Scaffold(
      appBar: _brandedMonthAppBar(context, month),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          await context.read<StatsCubit>().refresh();
          await Future.delayed(const Duration(milliseconds: 350));
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                6,
                horizontalPadding,
                18,
              ),
              children: [
                PeriodChips(
                  forMonth: month,
                  selected: period,
                  preview: state.preview,
                  onSelected: (p) => context.read<StatsCubit>().setPeriod(p),
                ),

                const SizedBox(height: 8),

                // KPIs ????
                if (state.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.error != null)
                  Text(
                    AppStrings.loadFailed(
                      AppStrings.summaryLabel,
                      state.error ?? 'unknown',
                    ),
                  )
                else if (state.overview != null)
                  KpiWrap(
                    items: [
                      Kpi(
                        AppStrings.totalSalesLabel,
                        state.overview!.kpis.sales.toStringAsFixed(2),
                        Icons.attach_money,
                      ),
                      Kpi(
                        AppStrings.costLabelDefinite,
                        state.overview!.kpis.cost.toStringAsFixed(2),
                        Icons.factory,
                      ),
                      Kpi(
                        AppStrings.profitLabelDefinite,
                        state.overview!.kpis.profit.toStringAsFixed(2),
                        Icons.trending_up,
                      ),
                      Kpi(
                        AppStrings.cupsLabel,
                        state.overview!.kpis.cups.toStringAsFixed(0),
                        Icons.local_cafe,
                      ),
                      Kpi(
                        AppStrings.snacksLabel,
                        state.overview!.kpis.units.toStringAsFixed(0),
                        Icons.cookie_rounded,
                      ),
                      Kpi(
                        AppStrings.coffeeGramsLabel,
                        state.overview!.kpis.grams.toStringAsFixed(0),
                        Icons.scale,
                      ),
                      Kpi(
                        AppStrings.expensesTitle,
                        state.overview!.kpis.expenses.toStringAsFixed(2),
                        Icons.account_balance_wallet,
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                /*
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            AppStrings.previousMonthsTitle,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.previousLoading)
                          const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.previousError != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              AppStrings.loadFailed(
                                AppStrings.previousMonthsTitle,
                                state.previousError ?? 'unknown',
                              ),
                            ),
                          )
                        else if (state.previousMonths.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(AppStrings.noDataForRange),
                          )
                        else
                          PreviousMonthsTable(
                            months: state.previousMonths,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                */
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            AppStrings.turkishCoffeeTitle,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.loading)
                          const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              AppStrings.loadFailed(
                                AppStrings.turkishCoffeeTitle,
                                state.error ?? 'unknown',
                              ),
                            ),
                          )
                        else if (state.overview != null)
                          Builder(
                            builder: (context) {
                              final rows = state.overview!.turkish.map((x) {
                                final plain = x.plainGrams.round();
                                final spiced = x.spicedGrams.round();
                                final cups = x.cups > 0
                                    ? x.cups
                                    : (plain + spiced);
                                return TurkishRow(
                                  name: x.name,
                                  cups: cups,
                                  plainCups: plain,
                                  spicedCups: spiced,
                                  sales: x.sales,
                                  cost: x.cost,
                                );
                              }).toList();
                              final totalCups = rows.fold<int>(
                                0,
                                (s, r) => s + r.cups,
                              );
                              if (rows.isEmpty) {
                                return TurkishCoffeeTable(rows: rows);
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      AppStrings.turkishCoffeeTotalCups(
                                        totalCups,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TurkishCoffeeTable(rows: rows),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ???? ?????? ?????????
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            AppStrings.dailyHighlightsTitle,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.loading)
                          const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              AppStrings.loadFailed(
                                AppStrings.dailyHighlightsLabel,
                                state.error ?? 'unknown',
                              ),
                            ),
                          )
                        else if (state.overview != null)
                          StatsHighlightsCard(
                            highlights: state.overview!.highlights,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ???? ??? ?????
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            AppStrings.beansByNameTitle,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.loading)
                          const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              AppStrings.loadFailed(
                                AppStrings.beansDataLabel,
                                state.error ?? 'unknown',
                              ),
                            ),
                          )
                        else if (state.overview != null)
                          Builder(
                            builder: (context) {
                              final rows = state.overview!.beans
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            AppStrings.drinksAndSnacksTitle,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.loading)
                          const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              AppStrings.loadFailed(
                                AppStrings.drinksDataLabel,
                                state.error ?? 'unknown',
                              ),
                            ),
                          )
                        else if (state.overview != null)
                          Builder(
                            builder: (context) {
                              final bundle = state.overview!;
                              final drinkRows = bundle.drinks
                                  .where(
                                    (x) => !_isTurkishName(_baseName(x.name)),
                                  )
                                  .map(
                                    (x) => DrinkRow(
                                      name: x.name,
                                      cups: x.cups,
                                      sales: x.sales,
                                      cost: x.cost,
                                      profit: x.profit,
                                      avgPrice: x.cups > 0
                                          ? (x.sales / x.cups)
                                          : 0,
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
                                      avgPrice: x.cups > 0
                                          ? (x.sales / x.cups)
                                          : 0,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            AppStrings.salesProfitTrendTitle,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.loading)
                          const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.error != null)
                          Text(
                            AppStrings.loadFailed(
                              AppStrings.trendLabel,
                              state.error ?? 'unknown',
                            ),
                          )
                        else if (state.overview != null)
                          Builder(
                            builder: (context) {
                              final t = state.overview!.trends;
                              return SalesProfitTrendChart(
                                sales: t.totalSales,
                                profit: t.totalProfit,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            AppStrings.beansGramsTrendTitle,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.loading)
                          const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.error != null)
                          Text(
                            AppStrings.loadFailed(
                              AppStrings.trendLabel,
                              state.error ?? 'unknown',
                            ),
                          )
                        else if (state.overview != null)
                          Builder(
                            builder: (context) {
                              final t = state.overview!.trends;
                              return DetailTrendChart(
                                primary: t.beansGrams,
                                sales: t.beansSales,
                                profit: t.beansProfit,
                                primaryLegend: AppStrings.beansGramsLegend,
                                primaryTooltipLabel:
                                    AppStrings.coffeeGramsLabel,
                                primaryColor: const Color(0xFFF4511E),
                                primaryAsInt: false,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            AppStrings.turkishTrendTitle,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.loading)
                          const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.error != null)
                          Text(
                            AppStrings.loadFailed(
                              AppStrings.trendLabel,
                              state.error ?? 'unknown',
                            ),
                          )
                        else if (state.overview != null)
                          Builder(
                            builder: (context) {
                              final t = state.overview!.trends;
                              return DetailTrendChart(
                                primary: t.turkishCups,
                                sales: t.turkishSales,
                                profit: t.turkishProfit,
                                primaryLegend: AppStrings.cupsLabel,
                                primaryTooltipLabel: AppStrings.cupsLabel,
                                primaryColor: const Color(0xFF6D4C41),
                                primaryAsInt: true,
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
            icon: const Icon(Icons.home_rounded, color: Colors.white),
            onPressed: () => context.read<NavCubit>().setTab(AppTab.home),
            tooltip: AppStrings.tabHome,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.white,
                ),
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
