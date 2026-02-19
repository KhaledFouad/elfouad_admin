import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/history/feature.dart'
    show HistoryPartialPayment, SalesHistoryCubit;
import 'package:elfouad_admin/presentation/history/utils/sale_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PartialPaymentTile extends StatefulWidget {
  const PartialPaymentTile({super.key, required this.payment});

  final HistoryPartialPayment payment;

  @override
  State<PartialPaymentTile> createState() => _PartialPaymentTileState();
}

class _PartialPaymentTileState extends State<PartialPaymentTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payment = widget.payment;
    final customerName = payment.customerName.trim();
    final title = customerName.isEmpty
        ? AppStrings.labelDeferredShort
        : '${AppStrings.labelDeferredShort} - $customerName';

    final tile = ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      collapsedBackgroundColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      leading: const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFE3F2E8),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          color: Color(0xFF2E7D32),
          size: 18,
        ),
      ),
      title: _PartialPaymentTitleRow(
        title: title,
        timeLabel: formatTime(payment.at),
      ),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _PartialPaymentValue(
            label: AppStrings.partialPaymentAmountLabel,
            value: payment.amount,
          ),
          if (_busy)
            const SizedBox(
              width: 36,
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: AppStrings.actionEdit,
                  onPressed: _editPayment,
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: AppStrings.actionDelete,
                  onPressed: _deletePayment,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
        ],
      ),
      children: const [
        Padding(
          padding: EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 10),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.black54),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppStrings.partialPaymentRegisteredHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 0.4,
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: tile,
      ),
    );
  }

  Future<void> _editPayment() async {
    if (_busy || !mounted) return;
    final controller = TextEditingController(
      text: widget.payment.amount.toStringAsFixed(2),
    );

    final raw = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.partialPaymentEditTitle),
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
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(AppStrings.actionSave),
          ),
        ],
      ),
    );

    final parsed = _parseAmount(raw);
    if (parsed == null || parsed <= 0) {
      _showSnack(AppStrings.errorEnterValidAmount);
      return;
    }
    if ((parsed - widget.payment.amount).abs() <= 0.000001) return;

    setState(() => _busy = true);
    try {
      await context.read<SalesHistoryCubit>().updatePartialPayment(
        payment: widget.payment,
        newAmount: parsed,
      );
      if (!mounted) return;
      _showSnack(AppStrings.partialPaymentUpdated);
    } catch (error) {
      if (!mounted) return;
      _showSnack(AppStrings.saveFailed(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePayment() async {
    if (_busy || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.partialPaymentDeleteTitle),
        content: const Text(AppStrings.partialPaymentDeleteConfirm),
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
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await context.read<SalesHistoryCubit>().deletePartialPayment(
        payment: widget.payment,
      );
      if (!mounted) return;
      _showSnack(AppStrings.partialPaymentDeleted);
    } catch (error) {
      if (!mounted) return;
      _showSnack(AppStrings.saveFailed(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  double? _parseAmount(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
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

class _PartialPaymentTitleRow extends StatelessWidget {
  const _PartialPaymentTitleRow({required this.title, required this.timeLabel});

  final String title;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontWeight: FontWeight.w700);
    const timeStyle = TextStyle(fontSize: 12, color: Colors.black54);

    final badges = Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _PartialPaymentBadge(),
        Text(timeLabel, style: timeStyle),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textStyle, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              badges,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: textStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            badges,
          ],
        );
      },
    );
  }
}

class _PartialPaymentBadge extends StatelessWidget {
  const _PartialPaymentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        AppStrings.partialPaymentBadge,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.green.shade800,
        ),
      ),
    );
  }
}

class _PartialPaymentValue extends StatelessWidget {
  const _PartialPaymentValue({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.black54)),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
