import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/data/repo/sales_history_repository.dart';
import '../bloc/sales_history_cubit.dart';
import 'credit_accounts_page.dart';
import '../models/history_summary.dart';
import '../widgets/history_day_section.dart';
import '../widgets/summary_pill.dart';
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
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final isWide = breakpoints.largerThan(TABLET);
    final contentMaxWidth = isWide ? 1100.0 : double.infinity;
    final horizontalPadding = isPhone ? 10.0 : 16.0;
    final listPadding = EdgeInsets.fromLTRB(
      horizontalPadding,
      12,
      horizontalPadding,
      24,
    );
    final showInitialLoading =
        state.isLoadingFirst && state.isEmpty && state.creditAccounts.isEmpty;
    final noHistoryLabel = state.isFiltered
        ? AppStrings.labelNoSalesInRange
        : AppStrings.labelNoSales;
    final summary = state.summary;
    final salesOverride = state.fullTotalsByDay.isNotEmpty
        ? state.fullTotalsByDay.values.fold<double>(
            0.0,
            (total, value) => total + value,
          )
        : null;
    final summaryForDisplay = summary != null && salesOverride != null
        ? summary.copyWith(sales: salesOverride)
        : summary;
    final rangeDays = state.range.end.difference(state.range.start).inDays;
    final showOverallSummary = summaryForDisplay != null && rangeDays > 1;
    final showSummaryLoading =
        summaryForDisplay == null && state.isSummaryLoading && rangeDays > 1;

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
                        constraints: BoxConstraints(maxWidth: contentMaxWidth),
                        child: RefreshIndicator.adaptive(
                          onRefresh: cubit.refreshCurrent,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: listPadding,
                            children: [
                              if (showOverallSummary)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _HistorySummary(
                                    summary: summaryForDisplay,
                                  ),
                                ),
                              if (showSummaryLoading)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
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
                                      summary: state.summaryByDay[group.label],
                                      showTotalLoading: showLoading,
                                    ),
                                  );
                                }),
                            ],
                          ),
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => AwesomeDrawerBar.of(context)?.toggle(),
            ),
            actions: [
              IconButton(
                tooltip: AppStrings.tooltipFilterByDate,
                onPressed: () => _showFilterActions(context, cubit),
                icon: const Icon(Icons.filter_alt, color: Colors.white),
              ),
              if (state.isFiltered)
                IconButton(
                  tooltip: AppStrings.tooltipClearFilter,
                  onPressed: () async => cubit.setRange(null),
                  icon: const Icon(Icons.clear),
                ),
            ],
            centerTitle: true,
            title: const Text(
              AppStrings.tabHistory,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 35,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.transparent,

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
      ),
    );
  }

  Future<void> _pickRange(BuildContext context, SalesHistoryCubit cubit) async {
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

  Future<void> _showFilterActions(
    BuildContext context,
    SalesHistoryCubit cubit,
  ) async {
    final action = await showModalBottomSheet<_HistoryFilterAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                AppStrings.filterAndExportTitle,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text(AppStrings.selectRange),
                onTap: () =>
                    Navigator.pop(context, _HistoryFilterAction.selectRange),
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text(AppStrings.exportExcelCsv),
                onTap: () =>
                    Navigator.pop(context, _HistoryFilterAction.exportRange),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    switch (action) {
      case _HistoryFilterAction.selectRange:
        await _pickRange(context, cubit);
        break;
      case _HistoryFilterAction.exportRange:
        await _exportRange(context, cubit);
        break;
      case null:
        break;
    }
  }

  Future<void> _exportRange(
    BuildContext context,
    SalesHistoryCubit cubit,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await cubit.exportRangeCsv();
      if (!context.mounted) return;
      if (path == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.noSalesInRangeForExport)),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.savedToPath(path))),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.exportFailed(error))),
      );
    }
  }
}

enum _HistoryFilterAction { selectRange, exportRange }

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
          heroTag: 'history_fab',
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
    final background = count > 0
        ? Colors.orange.shade700
        : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
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

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.summary});

  final HistorySummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        SummaryPill(
          icon: Icons.attach_money,
          label: AppStrings.salesLabel,
          value: summary.sales.toStringAsFixed(2),
        ),
        SummaryPill(
          icon: Icons.factory,
          label: AppStrings.costLabel,
          value: summary.cost.toStringAsFixed(2),
        ),
        SummaryPill(
          icon: Icons.trending_up,
          label: AppStrings.profitLabel,
          value: summary.profit.toStringAsFixed(2),
        ),
        SummaryPill(
          icon: Icons.local_cafe,
          label: AppStrings.drinksLabel,
          value: summary.drinks.toString(),
        ),
        SummaryPill(
          icon: Icons.cookie_rounded,
          label: AppStrings.snacksLabel,
          value: summary.snacks.toString(),
        ),
        SummaryPill(
          icon: Icons.scale,
          label: AppStrings.gramsCoffeeLabel,
          value: summary.grams.toStringAsFixed(0),
        ),
      ],
    );
  }
}
