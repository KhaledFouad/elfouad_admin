import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:elfouad_admin/core/utils/app_strings.dart';
import '../models/sale_component.dart';
import '../models/sale_record.dart';
import '../bloc/sales_history_cubit.dart';
import '../utils/sale_utils.dart';
import 'sale_edit_sheet.dart';

class SaleTile extends StatelessWidget {
  const SaleTile({super.key, required this.record});

  final SaleRecord record;

  @override
  Widget build(BuildContext context) {
    final isDeferredUnpaid = record.isDeferred && !record.isPaid;
    final theme = Theme.of(context);
    final tileBackground = isDeferredUnpaid
        ? deferredTileColor(record.note)
        : theme.colorScheme.surface;
    final borderColor = isDeferredUnpaid
        ? deferredBorderColor(record.note)
        : theme.dividerColor.withValues(alpha: 0.1);
    final totalPrice = record.totalPrice;
    final totalCost = record.totalCost;
    final profit = record.isComplimentary
        ? 0.0
        : parseDouble(record.data['profit_total']);
    final resolvedProfit = record.isComplimentary
        ? 0.0
        : (profit != 0 ? profit : (totalPrice - totalCost));

    final tile = ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      collapsedBackgroundColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isDeferredUnpaid
            ? deferredBaseColor(record.note)
            : Colors.brown.shade100,
        child: Icon(
          _iconForType(record.type),
          color: Colors.brown.shade700,
          size: 18,
        ),
      ),
      title: _TitleRow(record: record),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _KeyValue(label: AppStrings.labelInvoiceTotal, value: totalPrice),
          _KeyValue(label: AppStrings.costLabelDefinite, value: totalCost),
          _KeyValue(
            label: AppStrings.profitLabelDefinite,
            value: resolvedProfit,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppStrings.actionEdit,
                onPressed: () => _handleEdit(context),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: AppStrings.actionDelete,
                onPressed: () => _handleDelete(context),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
      children: [
        if (record.components.isEmpty)
          const ListTile(title: Text(AppStrings.toastNoBlendComponents))
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: record.components
                  .map((component) => _ComponentRow(component: component))
                  .toList(),
            ),
          ),
        if (record.usesSettledTime)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.brown),
                const SizedBox(width: 6),
                Text(
                  AppStrings.originalDateLabel(record.originalDateTimeLabel),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (record.canSettle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _SettleButton(record: record),
            ),
          ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tileBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isDeferredUnpaid ? 1.2 : 0.4,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: tile,
      ),
    );
  }

  Future<void> _handleEdit(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SaleEditSheet(snap: record.snapshot),
    );
    if (result == true && context.mounted) {
      await context.read<SalesHistoryCubit>().refreshCurrent();
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.deleteSaleTitle),
        content: const Text(
          AppStrings.deleteSaleConfirm,
          textAlign: TextAlign.center,
        ),
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

    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<SalesHistoryCubit>();
    try {
      await cubit.deleteSale(record.id);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.saleDeletedRollback)),
        );
      }
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.saleDeleteFailed(error))),
        );
      }
    }
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.record});

  final SaleRecord record;

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(fontWeight: FontWeight.w700);
    final timeStyle = const TextStyle(fontSize: 12, color: Colors.black54);

    final badges = Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (record.isComplimentary)
          _Chip(
            label: AppStrings.labelHospitality,
            border: Colors.orange.shade200,
            fill: Colors.orange.shade50,
          ),
        if (record.isDeferred && !record.isPaid)
          DeferredBadge(note: record.note),
        if (record.isDeferred && record.isPaid)
          _Chip(
            label: AppStrings.labelDeferredPast,
            border: Colors.orange.shade200,
            fill: Colors.orange.shade50,
          ),
        if (record.isDeferred && record.isPaid)
          _Chip(
            label: AppStrings.labelPaid,
            border: Colors.green.shade200,
            fill: Colors.green.shade50,
          ),
        Text(record.displayTime, style: timeStyle),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.titleLine,
                style: textStyle,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              badges,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                record.titleLine,
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

class DeferredBadge extends StatelessWidget {
  const DeferredBadge({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final background = deferredTileColor(note);
    final border = deferredBorderColor(note);
    final textColor = deferredTextColor(note);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color.lerp(background, Colors.white, 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.labelDeferredShort,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: textColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.border, required this.fill});

  final String label;
  final Color border;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

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

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final SaleComponent component;

  @override
  Widget build(BuildContext context) {
    final label = component.label;
    final quantity = component.quantityLabel(normalizeUnit);
    final addons = <String>[];
    if (component.spicedEnabled == true) {
      addons.add(
        component.spiced == true
            ? AppStrings.labelSpiced
            : AppStrings.labelPlain,
      );
    }
    if (component.ginsengGrams > 0) {
      addons.add(
        '${AppStrings.labelGinseng} ${component.ginsengGrams} ${AppStrings.labelGramsShort}',
      );
    }
    final subtitle = addons.isEmpty ? null : addons.join(' • ');

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.circle, size: 8),
      title: Text(label),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quantity.isNotEmpty)
            Text(quantity, style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 12),
          Text(
            AppStrings.priceLine(component.lineTotalPrice),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SettleButton extends StatelessWidget {
  const _SettleButton({required this.record});

  final SaleRecord record;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFF543824)),
      ),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text(AppStrings.dialogConfirmPayment),
            content: Text(
              AppStrings.confirmSettleAmount(
                record.outstandingAmount > 0
                    ? record.outstandingAmount
                    : record.totalPrice,
              ),
            ),
            actions: [
              TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    const Color.fromARGB(255, 242, 240, 240),
                  ),
                  foregroundColor: WidgetStateProperty.all(Colors.brown),
                  overlayColor: WidgetStateProperty.all(Colors.brown.shade50),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  AppStrings.dialogCancel,
                  style: TextStyle(color: Colors.brown),
                ),
              ),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    const Color(0xFF543824),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(AppStrings.dialogConfirm),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final cubit = context.read<SalesHistoryCubit>();
          try {
            await cubit.settleDeferredSale(record.id);
            messenger.showSnackBar(
              const SnackBar(content: Text(AppStrings.dialogDeferredSettled)),
            );
          } catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text(AppStrings.deferredSettleFailed(error))),
            );
          }
        }
      },
      icon: const Icon(Icons.payments),
      label: const Text(AppStrings.dialogPaymentDone),
    );
  }
}

IconData _iconForType(String type) {
  switch (type) {
    case 'drink':
      return Icons.local_cafe;
    case 'single':
      return Icons.coffee_outlined;
    case 'ready_blend':
      return Icons.blender_outlined;
    case 'custom_blend':
      return Icons.auto_awesome_mosaic;
    case 'extra':
      return Icons.cookie_rounded;
    default:
      return Icons.receipt_long;
  }
}
