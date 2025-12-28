import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/core/widgets/branded_appbar.dart';

import '../bloc/sales_history_cubit.dart';
import '../bloc/sales_history_state.dart';
import 'credit_customer_page.dart';
import '../widgets/credit_accounts_section.dart';

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const BrandedAppBar(
          title: AppStrings.titleCreditAccounts,
          showBack: true,
        ),
        body: BlocBuilder<SalesHistoryCubit, SalesHistoryState>(
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              children: [
                CreditAccountsSection(
                  accounts: state.creditAccounts,
                  isLoading: state.isCreditLoading,
                  onSelect: (account) {
                    final cubit = context.read<SalesHistoryCubit>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: cubit,
                          child: CreditCustomerPage(customerName: account.name),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
