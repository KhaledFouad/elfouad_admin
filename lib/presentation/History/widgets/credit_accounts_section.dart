import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

import '../models/credit_account.dart';

class CreditAccountsSection extends StatelessWidget {
  const CreditAccountsSection({
    super.key,
    required this.accounts,
    required this.isLoading,
    required this.onSelect,
    required this.onDelete,
  });

  final List<CreditCustomerAccount> accounts;
  final bool isLoading;
  final ValueChanged<CreditCustomerAccount> onSelect;
  final ValueChanged<CreditCustomerAccount> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppStrings.titleCreditAccounts,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  AppStrings.labelNoCreditAccounts,
                  style: const TextStyle(color: Colors.black54),
                ),
              )
            else
              Column(
                children: accounts
                    .map(
                      (account) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CreditAccountTile(
                          account: account,
                          onTap: () => onSelect(account),
                          onDelete: () => onDelete(account),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreditAccountTile extends StatelessWidget {
  const _CreditAccountTile({
    required this.account,
    required this.onTap,
    required this.onDelete,
  });

  final CreditCustomerAccount account;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final totalOwed = account.totalOwed;
    final hasDebt = totalOwed > 0;
    final initial = account.name.isNotEmpty ? account.name[0] : '#';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasDebt ? Colors.orange.shade300 : Colors.brown.shade200,
            ),
            color: hasDebt ? Colors.orange.shade50 : Colors.brown.shade50,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.brown.shade100,
                foregroundColor: const Color(0xFF543824),
                child: Text(initial),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppStrings.labelTotalOwed}: ${totalOwed.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: hasDebt
                            ? Colors.orange.shade900
                            : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${AppStrings.labelUnpaid}: ${account.unpaidCount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${AppStrings.labelPaid}: ${account.paidCount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: AppStrings.actionDelete,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.brown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
