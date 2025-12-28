import 'dart:math' as math;

import 'package:elfouad_admin/presentation/History/models/payment_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/core/widgets/branded_appbar.dart';

import '../bloc/sales_history_cubit.dart';
import '../bloc/sales_history_state.dart';
import '../models/credit_account.dart';
import '../models/sale_component.dart';
import '../models/sale_record.dart';
import '../utils/sale_utils.dart';

class CreditCustomerPage extends StatefulWidget {
  const CreditCustomerPage({super.key, required this.customerName});

  final String customerName;

  @override
  State<CreditCustomerPage> createState() => _CreditCustomerPageState();
}

class _CreditCustomerPageState extends State<CreditCustomerPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: BrandedAppBar(
          title: widget.customerName,
          showBack: true,
        ),
        body: BlocBuilder<SalesHistoryCubit, SalesHistoryState>(
          builder: (context, state) {
            final account = _findAccount(state, widget.customerName);
            if (account == null) {
              if (state.isCreditLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return Center(child: Text(AppStrings.labelNoCreditAccounts));
            }

            final totalOwed = account.totalOwed;
            final sales = account.sales;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: _AccountHeader(
                    account: account,
                    totalOwed: totalOwed,
                    busy: _busy,
                    onPayAmount: totalOwed <= 0 || _busy
                        ? null
                        : () => _handlePayAmount(account),
                  ),
                ),
                Expanded(
                  child: sales.isEmpty
                      ? Center(
                          child: Text(AppStrings.labelNoCreditSalesForCustomer),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: sales.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final record = sales[index];
                            return _CreditSaleTile(
                              record: record,
                              busy: _busy,
                              onPay: record.outstandingAmount > 0 && !_busy
                                  ? () => _handlePaySale(record)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  CreditCustomerAccount? _findAccount(
    SalesHistoryState state,
    String customerName,
  ) {
    final target = customerName.trim();
    for (final account in state.creditAccounts) {
      if (account.name == target) {
        return account;
      }
    }
    return null;
  }

  Future<void> _handlePaySale(SaleRecord record) async {
    if (_busy) return;
    final due = record.outstandingAmount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.dialogConfirmPayment),
        content: Text(AppStrings.confirmSettleAmount(due)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.dialogConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final cubit = context.read<SalesHistoryCubit>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await cubit.settleDeferredSale(record.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.dialogDeferredSettled)),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.deferredSettleFailed(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePayAmount(CreditCustomerAccount account) async {
    if (_busy) return;
    final raw = await _promptAmount();
    if (raw == null) return;
    final amount = _parseAmount(raw);
    if (amount == null || amount <= 0) {
      _showError(AppStrings.errorEnterValidAmount);
      return;
    }

    final totalOwed = account.totalOwed;
    if (totalOwed <= 0) return;

    final amountToPay = math.min(amount, totalOwed);
    if (amountToPay <= 0) return;

    if (amount > totalOwed) {
      _showError(AppStrings.creditPaymentExceedsTotal);
    }

    final cubit = context.read<SalesHistoryCubit>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await cubit.applyCreditPayment(
        customerName: account.name,
        amount: amountToPay,
      );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.dialogPaymentDone)),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.deferredSettleFailed(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptAmount() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.dialogPayAmountTitle),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: AppStrings.hintExample100,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(AppStrings.dialogConfirm),
          ),
        ],
      ),
    );
    return result?.trim().isEmpty == true ? null : result;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double? _parseAmount(String raw) {
    final normalized = _normalizeNumberString(raw);
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _normalizeNumberString(String input) {
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      switch (unit) {
        case 0x0660:
          buffer.write('0');
          continue;
        case 0x0661:
          buffer.write('1');
          continue;
        case 0x0662:
          buffer.write('2');
          continue;
        case 0x0663:
          buffer.write('3');
          continue;
        case 0x0664:
          buffer.write('4');
          continue;
        case 0x0665:
          buffer.write('5');
          continue;
        case 0x0666:
          buffer.write('6');
          continue;
        case 0x0667:
          buffer.write('7');
          continue;
        case 0x0668:
          buffer.write('8');
          continue;
        case 0x0669:
          buffer.write('9');
          continue;
        case 0x06F0:
          buffer.write('0');
          continue;
        case 0x06F1:
          buffer.write('1');
          continue;
        case 0x06F2:
          buffer.write('2');
          continue;
        case 0x06F3:
          buffer.write('3');
          continue;
        case 0x06F4:
          buffer.write('4');
          continue;
        case 0x06F5:
          buffer.write('5');
          continue;
        case 0x06F6:
          buffer.write('6');
          continue;
        case 0x06F7:
          buffer.write('7');
          continue;
        case 0x06F8:
          buffer.write('8');
          continue;
        case 0x06F9:
          buffer.write('9');
          continue;
        case 0x066B:
          buffer.write('.');
          continue;
        case 0x066C:
          continue;
      }
      final ch = String.fromCharCode(unit);
      if ((ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) ||
          ch == '.' ||
          ch == '-') {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.account,
    required this.totalOwed,
    required this.busy,
    required this.onPayAmount,
  });

  final CreditCustomerAccount account;
  final double totalOwed;
  final bool busy;
  final VoidCallback? onPayAmount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              account.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${AppStrings.labelTotalOwed}: ${totalOwed.toStringAsFixed(2)}',
              style: TextStyle(
                color: totalOwed > 0 ? Colors.orange.shade900 : Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${AppStrings.labelUnpaid}: ${account.unpaidCount}'),
                const SizedBox(width: 12),
                Text('${AppStrings.labelPaid}: ${account.paidCount}'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: busy ? null : onPayAmount,
                icon: const Icon(Icons.payments_outlined),
                label: const Text(AppStrings.btnPayAmount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditSaleTile extends StatelessWidget {
  const _CreditSaleTile({
    required this.record,
    required this.busy,
    required this.onPay,
  });

  final SaleRecord record;
  final bool busy;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final due = record.outstandingAmount;
    final isPaid = due <= 0;
    final settledAt = record.settledAt;
    final paymentEvents = List.of(record.paymentEvents)
      ..sort((a, b) => b.at.compareTo(a.at));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.titleLine,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusChip(
                  label: isPaid ? AppStrings.labelPaid : AppStrings.labelUnpaid,
                  color: isPaid
                      ? Colors.green.shade600
                      : Colors.orange.shade800,
                  background: isPaid
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${AppStrings.labelSaleDate}: ${formatDateTime(record.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (isPaid && settledAt != null)
              Text(
                '${AppStrings.labelPaidAt}: ${formatDateTime(settledAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  isPaid
                      ? '${AppStrings.labelInvoiceTotal}: ${record.totalPrice.toStringAsFixed(2)}'
                      : '${AppStrings.labelAmountDue}: ${due.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: isPaid ? FontWeight.w600 : FontWeight.w700,
                    color: isPaid ? Colors.black87 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            if (record.components.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Column(
                children: record.components
                    .map((component) => _ComponentRow(component: component))
                    .toList(),
              ),
            ],
            if (paymentEvents.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  AppStrings.labelPartialPayments,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Column(
                children: paymentEvents
                    .map((event) => _PaymentEventRow(event: event))
                    .toList(),
              ),
            ],
            if (!isPaid)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onPay,
                    icon: const Icon(Icons.payments),
                    label: const Text(AppStrings.btnPaySale),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final SaleComponent component;

  @override
  Widget build(BuildContext context) {
    final quantity = component.quantityLabel(normalizeUnit);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.brown),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              component.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (quantity.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              quantity,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(width: 8),
          Text(
            AppStrings.priceLine(component.lineTotalPrice),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PaymentEventRow extends StatelessWidget {
  const _PaymentEventRow({required this.event});

  final PaymentEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, size: 16, color: Colors.brown),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.partialPaymentLine(
                event.amount,
                formatDateTime(event.at),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
