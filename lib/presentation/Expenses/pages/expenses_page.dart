import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/domain/entities/expense.dart' show Expense;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../bloc/expenses_cubit.dart';
import '../utils/expenses_utils.dart';
import '../widgets/expense_edit_sheet.dart';
import '../widgets/expense_summary_pill.dart';
import '../widgets/expenses_list.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});
  static const route = '/expenses';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExpensesCubit>().state;
    final range = state.range;
    final total = state.total;
    final list = state.items;
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final isWide = breakpoints.largerThan(TABLET);
    final contentMaxWidth = isWide ? 1100.0 : double.infinity;
    final horizontalPadding = isPhone ? 10.0 : 16.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: PreferredSize(
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
              title: const Text(
                AppStrings.expensesTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 35,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 8,
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  tooltip: AppStrings.actionFilterByDate,
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(DateTime.now().year - 2),
                      lastDate: DateTime(DateTime.now().year + 1),
                      initialDateRange: range,
                      locale: const Locale('ar'),
                      builder: (context, child) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: child!,
                      ),
                    );
                    if (!context.mounted) return;
                    if (picked != null) {
                      final start = DateTime(
                        picked.start.year,
                        picked.start.month,
                        picked.start.day,
                        4,
                      );
                      final endBase = DateTime(
                        picked.end.year,
                        picked.end.month,
                        picked.end.day,
                        4,
                      );
                      final end = endBase.add(const Duration(days: 1));
                      context.read<ExpensesCubit>().setRange(
                            DateTimeRange(start: start, end: end),
                          );
                    }
                  },
                  icon: const Icon(Icons.filter_alt_rounded),
                  color: Colors.white,
                ),
                if (range != todayOperationalRangeLocal())
                  IconButton(
                    tooltip: AppStrings.actionOperationalDay,
                    onPressed: () {
                      context
                          .read<ExpensesCubit>()
                          .setRange(todayOperationalRangeLocal());
                    },
                    icon: const Icon(Icons.restart_alt),
                    color: Colors.white,
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
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'expenses_fab',
          onPressed: () => _openEditSheet(context),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.expenseNew),
          backgroundColor: kDarkBrown,
          foregroundColor: Colors.white,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Column(
              children: [
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 4),
                  child: Row(
                    children: [
                      ExpenseSummaryPill(
                        label: AppStrings.totalLabel,
                        value: total.toStringAsFixed(2),
                        icon: Icons.account_balance_wallet,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                Expanded(
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                          ? Center(
                              child: Text(
                                AppStrings.expensesLoadError(
                                  state.error ?? 'unknown',
                                ),
                              ),
                            )
                          : list.isEmpty
                              ? const Center(
                                  child: Text(AppStrings.expensesEmptyRange),
                                )
                              : ExpensesList(
                                  items: list,
                                  horizontalPadding: horizontalPadding,
                                  onEdit: (e) => _openEditSheet(context, e),
                                  onDelete: (id) => _deleteExpense(context, id),
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteExpense(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.confirmDeleteTitle),
        content: const Text(AppStrings.expenseDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.actionDelete),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (ok == true) {
      await context.read<ExpensesCubit>().deleteExpense(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.expenseDeleted)),
        );
      }
    }
  }

  void _openEditSheet(BuildContext context, [Expense? e]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ExpenseEditSheet(expense: e),
    );
  }
}
