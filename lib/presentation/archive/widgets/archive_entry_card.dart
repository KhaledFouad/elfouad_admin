import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/history/feature.dart'
    show SaleComponent;
import 'package:elfouad_admin/presentation/history/utils/sale_utils.dart';
import 'package:elfouad_admin/presentation/archive/models/archive_entry.dart';
import 'package:elfouad_admin/presentation/archive/utils/archive_utils.dart';
import 'package:flutter/material.dart';

class ArchiveEntryCard extends StatelessWidget {
  const ArchiveEntryCard({
    super.key,
    required this.entry,
    required this.isRestoring,
    required this.onRestore,
  });

  final ArchiveEntry entry;
  final bool isRestoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    if (entry.kind == 'sale') {
      return _ArchivedSaleCard(
        entry: entry,
        isRestoring: isRestoring,
        onRestore: onRestore,
      );
    }

    final title = entryTitle(entry);
    final kind = kindLabel(entry.kind);
    final when = formatDateTime(entry.archivedAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title),
        subtitle: Text('$kind - $when'),
        trailing: TextButton.icon(
          onPressed: isRestoring ? null : onRestore,
          icon: const Icon(Icons.restore),
          label: const Text(AppStrings.actionRestore),
        ),
      ),
    );
  }
}

class _ArchivedSaleCard extends StatelessWidget {
  const _ArchivedSaleCard({
    required this.entry,
    required this.isRestoring,
    required this.onRestore,
  });

  final ArchiveEntry entry;
  final bool isRestoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final data = entry.data;
    final type = detectSaleType(data);
    final title = buildTitleLine(data, type);

    final createdAt =
        entry.createdAtOriginal ??
        parseDate(data['created_at'] ?? data['createdAt']);
    final settledAt = parseOptionalDate(data['settled_at']);
    final isComplimentary = (data['is_complimentary'] ?? false) == true;
    final isDeferred =
        (data['is_deferred'] ?? data['is_credit'] ?? false) == true;
    final isPaid = (data['paid'] ?? (!isDeferred)) == true;

    final effectiveTime = computeEffectiveTime(
      createdAt: createdAt,
      settledAt: settledAt,
      isDeferred: isDeferred,
      isPaid: isPaid,
    );
    final usesSettledTime = !isSameMinute(effectiveTime, createdAt);
    final displayTime = (isDeferred && isPaid)
        ? formatTime(createdAt)
        : formatTime(effectiveTime);

    final totalPrice = entry.totalPrice ?? parseDouble(data['total_price']);
    final totalCost = parseDouble(data['total_cost']);
    final rawProfit = parseDouble(data['profit_total']);
    final resolvedProfit = isComplimentary
        ? 0.0
        : (rawProfit != 0 ? rawProfit : (totalPrice - totalCost));

    final components = extractComponents(data, type);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.brown.shade100,
            child: Icon(
              _iconForType(type),
              color: Colors.brown.shade700,
              size: 18,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
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
              Text(
                displayTime,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              TextButton.icon(
                onPressed: isRestoring ? null : onRestore,
                icon: const Icon(Icons.restore),
                label: const Text(AppStrings.actionRestore),
              ),
            ],
          ),
          children: [
            if (components.isEmpty)
              const ListTile(title: Text(AppStrings.noComponentDetails))
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: components
                      .map(
                        (component) =>
                            _ArchiveComponentRow(component: component),
                      )
                      .toList(),
                ),
              ),
            if (usesSettledTime)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 16,
                  end: 16,
                  bottom: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 16, color: Colors.brown),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.originalDateLabel(formatDateTime(createdAt)),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 16,
                end: 16,
                bottom: 12,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.brown,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${AppStrings.recycleBinTitle}: ${formatDateTime(entry.archivedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveComponentRow extends StatelessWidget {
  const _ArchiveComponentRow({required this.component});

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
    case 'invoice':
      return Icons.receipt_long;
    default:
      return Icons.receipt_long;
  }
}
