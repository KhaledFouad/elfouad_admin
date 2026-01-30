import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/stats/models/stats_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PreviousMonthsTable extends StatelessWidget {
  const PreviousMonthsTable({super.key, required this.months});

  final List<MonthlyKpi> months;

  @override
  Widget build(BuildContext context) {
    final headerStyle = const TextStyle(fontWeight: FontWeight.w800);
    final formatter = DateFormat('MMM yyyy', 'ar');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
            label: Text(AppStrings.monthLabel, style: headerStyle),
          ),
          DataColumn(
            label: Text(AppStrings.salesLabelDefinite, style: headerStyle),
          ),
          DataColumn(
            label: Text(AppStrings.profitLabelDefinite, style: headerStyle),
          ),
          DataColumn(
            label: Text(AppStrings.cupsLabelShort, style: headerStyle),
          ),
          DataColumn(
            label: Text(AppStrings.gramsLabel, style: headerStyle),
          ),
          DataColumn(
            label: Text(AppStrings.snacksLabel, style: headerStyle),
          ),
        ],
        rows: months
            .map(
              (m) => DataRow(
                cells: [
                  DataCell(Text(formatter.format(m.month))),
                  DataCell(Text(m.kpis.sales.toStringAsFixed(2))),
                  DataCell(Text(m.kpis.profit.toStringAsFixed(2))),
                  DataCell(Text(m.kpis.cups.toString())),
                  DataCell(Text(m.kpis.grams.toStringAsFixed(0))),
                  DataCell(Text(m.kpis.units.toString())),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
