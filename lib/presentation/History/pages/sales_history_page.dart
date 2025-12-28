import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/data/repo/sales_history_repository.dart';
import '../bloc/sales_history_cubit.dart';
import 'credit_accounts_page.dart';
import '../widgets/history_day_section.dart';
import '../utils/sale_utils.dart';

class SalesHistoryPage extends StatelessWidget {
  const SalesHistoryPage({super.key});

  static const route = '/sales-history';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SalesHistoryCubit(
        repository: SalesHistoryRepository(FirebaseFirestore.instance),
      )..initialize(),
      child: const _SalesHistoryView(),
    );
  }
}

class _SalesHistoryView extends StatelessWidget {
  const _SalesHistoryView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SalesHistoryCubit>();
    final state = cubit.state;
    final width = MediaQuery.of(context).size.width;
    final contentMaxWidth = width >= 1100 ? 1100.0 : double.infinity;
    final horizontalPadding = width < 600 ? 10.0 : 12.0;
    final listPadding = EdgeInsets.fromLTRB(
      horizontalPadding,
      12,
      horizontalPadding,
      24,
    );
    final showInitialLoading =
        state.isLoadingFirst && state.isEmpty && state.creditAccounts.isEmpty;
    final noHistoryLabel =
        state.isFiltered ? AppStrings.labelNoSalesInRange : AppStrings.labelNoSales;
    final summary = state.groups.isEmpty
        ? null
        : _HistorySummaryData.fromRecords(
            state.groups.expand((group) => group.entries),
          );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _HistoryAppBar(cubit: cubit),
        floatingActionButton: _CreditFab(
          count: state.creditUnpaidCount,
          isLoading: state.isCreditCountLoading,
          onTap: () {
            final cubit = context.read<SalesHistoryCubit>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const CreditAccountsPage(),
                ),
              ),
            );
          },
        ),
        body: showInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: contentMaxWidth,
                        ),
                        child: ListView(
                          padding: listPadding,
                          children: [
                            if (summary != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _HistorySummary(summary: summary),
                              ),
                            if (state.groups.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Center(child: Text(noHistoryLabel)),
                              )
                            else
                              ...state.groups.map((group) {
                                final overrideTotal =
                                    state.fullTotalsByDay[group.label];
                                final showLoading =
                                    state.isRangeTotalLoading &&
                                    overrideTotal == null;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: HistoryDaySection(
                                    group: group,
                                    overrideTotal: overrideTotal,
                                    showTotalLoading: showLoading,
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (state.hasMore && !state.isLoadingFirst)
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentMaxWidth),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: cubit.loadMore,
                              child: const Text(AppStrings.btnLoadMore),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
            ),
      ),
    );
  }
}

class _HistoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HistoryAppBar({required this.cubit});

  final SalesHistoryCubit cubit;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final state = cubit.state;
    final width = MediaQuery.of(context).size.width;
    final canPop = Navigator.of(context).canPop();
    final titleSize = width < 600
        ? 22.0
        : width < 1024
            ? 26.0
            : width < 1400
                ? 28.0
                : 32.0;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            canPop ? Icons.arrow_back_ios_new_rounded : Icons.menu,
            color: Colors.white,
          ),
          onPressed: () {
            if (canPop) {
              Navigator.maybePop(context);
              return;
            }
            AwesomeDrawerBar.of(context)?.toggle();
          },
          tooltip: canPop ? AppStrings.tooltipBack : AppStrings.menuTooltip,
        ),
        title: Text(
          AppStrings.titleSalesHistory,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: titleSize,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 8,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: AppStrings.tooltipFilterByDate,
            onPressed: () => _pickRange(context, cubit),
            icon: const Icon(Icons.filter_alt, color: Colors.white),
          ),
          if (state.isFiltered)
            IconButton(
              tooltip: AppStrings.tooltipClearFilter,
              onPressed: () async => cubit.setRange(null),
              icon: const Icon(Icons.clear),
            ),
        ],
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
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    SalesHistoryCubit cubit,
  ) async {
    final now = DateTime.now();
    final init = cubit.state.customRange ?? defaultSalesRange();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: init,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );

    if (picked != null) {
      final normalized = cubit.normalizePickerRange(picked);
      await cubit.setRange(normalized);
    }
  }
}

class _CreditFab extends StatelessWidget {
  const _CreditFab({
    required this.count,
    required this.isLoading,
    required this.onTap,
  });

  final int count;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton.extended(
          onPressed: onTap,
          icon: const Icon(Icons.account_balance_wallet_rounded),
          label: const Text(AppStrings.titleCreditAccounts),
        ),
        if (count > 0 || isLoading)
          Positioned(
            top: -4,
            right: -4,
            child: _CreditBadge(count: count, isLoading: isLoading),
          ),
      ],
    );
  }
}

class _CreditBadge extends StatelessWidget {
  const _CreditBadge({required this.count, required this.isLoading});

  final int count;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final background = count > 0 ? Colors.orange.shade700 : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: isLoading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _HistorySummaryData {
  const _HistorySummaryData({
    required this.sales,
    required this.cost,
    required this.profit,
    required this.drinks,
    required this.snacks,
    required this.grams,
  });

  final double sales;
  final double cost;
  final double profit;
  final int drinks;
  final int snacks;
  final double grams;

  factory _HistorySummaryData.fromRecords(Iterable<SaleRecord> records) {
    double sales = 0;
    double cost = 0;
    double profit = 0;
    double grams = 0;
    int drinks = 0;
    int snacks = 0;

    for (final record in records) {
      final isComplimentary = record.isComplimentary;
      final totalPrice = isComplimentary ? 0.0 : record.totalPrice;
      final totalCost = record.totalCost;
      final rawProfit = isComplimentary
          ? 0.0
          : parseDouble(record.data['profit_total']);
      final resolvedProfit = isComplimentary
          ? 0.0
          : (rawProfit != 0 ? rawProfit : (totalPrice - totalCost));

      sales += totalPrice;
      cost += totalCost;
      profit += resolvedProfit;

      switch (record.type) {
        case 'drink':
          drinks += _recordQuantity(record);
          break;
        case 'extra':
          snacks += _recordQuantity(record);
          break;
        case 'single':
        case 'ready_blend':
          grams += _recordGrams(record, fallbackKey: 'grams');
          break;
        case 'custom_blend':
          grams += _recordGrams(record, fallbackKey: 'total_grams');
          break;
        default:
          final components = record.components;
          if (components.isNotEmpty) {
            for (final component in components) {
              if (component.grams > 0) {
                grams += component.grams;
                continue;
              }
              final qty = _roundQty(component.quantity);
              final unit = component.unit.trim().toLowerCase();
              if (_isSnackUnit(unit)) {
                snacks += qty;
              } else {
                drinks += qty;
              }
            }
          }
          break;
      }
    }

    return _HistorySummaryData(
      sales: sales,
      cost: cost,
      profit: profit,
      drinks: drinks,
      snacks: snacks,
      grams: grams,
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.summary});

  final _HistorySummaryData summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        _HistorySummaryPill(
          icon: Icons.attach_money,
          label: AppStrings.salesLabel,
          value: summary.sales.toStringAsFixed(2),
        ),
        _HistorySummaryPill(
          icon: Icons.factory,
          label: AppStrings.costLabel,
          value: summary.cost.toStringAsFixed(2),
        ),
        _HistorySummaryPill(
          icon: Icons.trending_up,
          label: AppStrings.profitLabel,
          value: summary.profit.toStringAsFixed(2),
        ),
        _HistorySummaryPill(
          icon: Icons.local_cafe,
          label: AppStrings.drinksLabel,
          value: summary.drinks.toString(),
        ),
        _HistorySummaryPill(
          icon: Icons.cookie_rounded,
          label: AppStrings.snacksLabel,
          value: summary.snacks.toString(),
        ),
        _HistorySummaryPill(
          icon: Icons.scale,
          label: AppStrings.gramsCoffeeLabel,
          value: summary.grams.toStringAsFixed(0),
        ),
      ],
    );
  }
}

class _HistorySummaryPill extends StatelessWidget {
  const _HistorySummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.brown.shade700),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

int _roundQty(double qty) => qty > 0 ? qty.round() : 1;

int _recordQuantity(SaleRecord record) {
  final byComponents = record.components.fold<double>(
    0.0,
    (sum, component) => sum + component.quantity,
  );
  final fallback = parseDouble(
    record.data['quantity'] ?? record.data['qty'],
  );
  final qty = byComponents > 0 ? byComponents : fallback;
  return _roundQty(qty);
}

double _recordGrams(SaleRecord record, {String? fallbackKey}) {
  final byComponents = record.components.fold<double>(
    0.0,
    (sum, component) => sum + component.grams,
  );
  if (byComponents > 0) return byComponents;
  if (fallbackKey != null) {
    final fallback = parseDouble(record.data[fallbackKey]);
    if (fallback > 0) return fallback;
  }
  return parseDouble(record.data['grams']);
}

bool _isSnackUnit(String unit) {
  if (unit.isEmpty) return false;
  if (unit == 'piece' || unit == 'pcs' || unit == 'pc') return true;
  return unit == AppStrings.labelPieceUnit;
}


