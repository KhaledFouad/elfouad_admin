import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../bloc/sales_history_cubit.dart';
import '../bloc/sales_history_state.dart';
import 'credit_customer_page.dart';
import '../widgets/credit_accounts_section.dart';
import '../models/credit_account.dart';
import '../models/history_summary.dart';
import '../models/sale_record.dart';
import '../widgets/summary_pill.dart';

class CreditAccountsPage extends StatefulWidget {
  const CreditAccountsPage({super.key});

  @override
  State<CreditAccountsPage> createState() => _CreditAccountsPageState();
}

class _CreditAccountsPageState extends State<CreditAccountsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesHistoryCubit>().loadCreditAccounts(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final isWide = breakpoints.largerThan(TABLET);
    final contentMaxWidth = isWide ? 1000.0 : double.infinity;
    final horizontalPadding = isPhone ? 10.0 : 16.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const _CreditAccountsAppBar(),
        body: BlocBuilder<SalesHistoryCubit, SalesHistoryState>(
          builder: (context, state) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    20,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CreditAccountsSummary(
                        summary: _summaryForAccounts(state.creditAccounts),
                        isLoading: state.isCreditLoading,
                      ),
                    ),
                    CreditAccountsSection(
                      accounts: state.creditAccounts,
                      isLoading: state.isCreditLoading,
                      onSelect: (account) {
                        final cubit = context.read<SalesHistoryCubit>();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: cubit,
                              child: CreditCustomerPage(
                                customerName: account.name,
                              ),
                            ),
                          ),
                        );
                      },
                      onRename: (account) => _promptRenameAccount(account),
                      onDelete: (account) => _confirmDeleteAccount(account),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(CreditCustomerAccount account) async {
    final hasUnpaid = account.unpaidCount > 0;
    final message = hasUnpaid
        ? AppStrings.confirmDeleteCreditAccountUnpaid
        : AppStrings.confirmDeleteCreditAccount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.confirmDeleteTitle),
        content: Text(message, textAlign: TextAlign.center),
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

    if (confirmed != true || !mounted) return;
    final cubit = context.read<SalesHistoryCubit>();
    try {
      await cubit.deleteCreditCustomer(account.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.creditAccountDeleted)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(error))));
    }
  }

  Future<void> _promptRenameAccount(CreditCustomerAccount account) async {
    final controller = TextEditingController(text: account.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.editCreditAccountNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: AppStrings.nameLabel),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(AppStrings.actionSave),
          ),
        ],
      ),
    );

    if (result == null) return;
    final newName = result.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.nameRequiredPrompt)),
      );
      return;
    }
    if (newName == account.name) return;

    final cubit = context.read<SalesHistoryCubit>();
    try {
      await cubit.renameCreditCustomer(oldName: account.name, newName: newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.creditAccountRenamed)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(error))));
    }
  }

  HistorySummary _summaryForAccounts(List<CreditCustomerAccount> accounts) {
    if (accounts.isEmpty) {
      return HistorySummary.empty();
    }
    final seen = <String>{};
    final records = <SaleRecord>[];
    for (final account in accounts) {
      for (final record in account.sales) {
        if (record.outstandingAmount <= 0) {
          continue;
        }
        if (seen.add(record.id)) {
          records.add(record);
        }
      }
    }
    return HistorySummary.fromRecords(records);
  }
}

class _CreditAccountsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _CreditAccountsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: AppStrings.tooltipBack,
        ),
        title: Text(
          AppStrings.titleCreditAccounts,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: titleSize,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 8,
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
    );
  }
}

class _CreditAccountsSummary extends StatelessWidget {
  const _CreditAccountsSummary({
    required this.summary,
    required this.isLoading,
  });

  final HistorySummary summary;
  final bool isLoading;

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
          isLoading: isLoading,
        ),
        SummaryPill(
          icon: Icons.factory,
          label: AppStrings.costLabel,
          value: summary.cost.toStringAsFixed(2),
          isLoading: isLoading,
        ),
        SummaryPill(
          icon: Icons.trending_up,
          label: AppStrings.profitLabel,
          value: summary.profit.toStringAsFixed(2),
          isLoading: isLoading,
        ),
        SummaryPill(
          icon: Icons.local_cafe,
          label: AppStrings.drinksLabel,
          value: summary.drinks.toString(),
          isLoading: isLoading,
        ),
        SummaryPill(
          icon: Icons.cookie_rounded,
          label: AppStrings.snacksLabel,
          value: summary.snacks.toString(),
          isLoading: isLoading,
        ),
        SummaryPill(
          icon: Icons.scale,
          label: AppStrings.gramsCoffeeLabel,
          value: summary.grams.toStringAsFixed(0),
          isLoading: isLoading,
        ),
      ],
    );
  }
}
