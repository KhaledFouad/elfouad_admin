import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

import '../models/history_summary.dart';
import '../models/history_partial_payment.dart';
import '../models/sale_record.dart';
import '../models/sales_day_group.dart';
import 'sale_tile.dart';
import 'partial_payment_tile.dart';
import 'summary_pill.dart';

class HistoryDaySection extends StatelessWidget {
  const HistoryDaySection({
    super.key,
    required this.group,
    this.overrideTotal,
    this.summary,
    this.showTotalLoading = false,
  });

  final SalesDayGroup group;
  final double? overrideTotal;
  final HistorySummary? summary;
  final bool showTotalLoading;

  @override
  Widget build(BuildContext context) {
    final baseSummary = summary ?? HistorySummary.fromRecords(group.entries);
    final daySummary = overrideTotal != null
        ? baseSummary.copyWith(sales: overrideTotal)
        : baseSummary;
    final salesLoading = showTotalLoading && overrideTotal == null;

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
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                SummaryPill(
                  icon: Icons.attach_money,
                  label: AppStrings.salesLabel,
                  value: daySummary.sales.toStringAsFixed(2),
                  isLoading: salesLoading,
                ),
                SummaryPill(
                  icon: Icons.factory,
                  label: AppStrings.costLabel,
                  value: daySummary.cost.toStringAsFixed(2),
                ),
                SummaryPill(
                  icon: Icons.trending_up,
                  label: AppStrings.profitLabel,
                  value: daySummary.profit.toStringAsFixed(2),
                ),
                SummaryPill(
                  icon: Icons.local_cafe,
                  label: AppStrings.drinksLabel,
                  value: daySummary.drinks.toString(),
                ),
                SummaryPill(
                  icon: Icons.cookie_rounded,
                  label: AppStrings.snacksLabel,
                  value: daySummary.snacks.toString(),
                ),
                SummaryPill(
                  icon: Icons.scale,
                  label: AppStrings.gramsCoffeeLabel,
                  value: daySummary.grams.toStringAsFixed(0),
                ),
              ],
            ),
            const Divider(height: 18),
            ..._timelineItems(group).map((item) {
              if (item.sale != null) {
                return SaleTile(record: item.sale!);
              }
              return PartialPaymentTile(payment: item.partialPayment!);
            }),
          ],
        ),
      ),
    );
  }

  List<_DayTimelineItem> _timelineItems(SalesDayGroup group) {
    final out = <_DayTimelineItem>[
      ...group.entries.map(
        (sale) => _DayTimelineItem(
          at: sale.effectiveTime,
          sale: sale,
          partialPayment: null,
        ),
      ),
      ...group.partialPayments.map(
        (payment) => _DayTimelineItem(
          at: payment.at,
          sale: null,
          partialPayment: payment,
        ),
      ),
    ];
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }
}

class _DayTimelineItem {
  const _DayTimelineItem({
    required this.at,
    required this.sale,
    required this.partialPayment,
  });

  final DateTime at;
  final SaleRecord? sale;
  final HistoryPartialPayment? partialPayment;
}
