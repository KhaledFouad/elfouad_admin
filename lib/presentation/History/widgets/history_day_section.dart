import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

import '../models/sales_day_group.dart';
import 'sale_tile.dart';

class HistoryDaySection extends StatelessWidget {
  const HistoryDaySection({
    super.key,
    required this.group,
    this.overrideTotal,
    this.showTotalLoading = false,
  });

  final SalesDayGroup group;
  final double? overrideTotal;
  final bool showTotalLoading;

  @override
  Widget build(BuildContext context) {
    final summaryValue = overrideTotal ?? group.totalPaid;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  group.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                _SummaryPill(
                  value: summaryValue,
                  isLoading: showTotalLoading && overrideTotal == null,
                ),
              ],
            ),
            const Divider(height: 18),
            ...group.entries.map((sale) => SaleTile(record: sale)),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.value, this.isLoading = false});

  final double value;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_money, size: 16),
          const SizedBox(width: 4),
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              AppStrings.salesAmount(value),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
