import 'package:elfouad_admin/presentation/stats/models/stats_models.dart'
    show GroupRow;
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

class BreakdownTable extends StatelessWidget {
  final List<GroupRow> rows;
  final bool showCups;
  final bool showGrams;
  const BreakdownTable({
    super.key,
    required this.rows,
    this.showCups = false,
    this.showGrams = false,
  });

  @override
  Widget build(BuildContext context) {
    final headerStyle = const TextStyle(fontWeight: FontWeight.w800);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(
            label: Text(
              AppStrings.typeLabel,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (showCups)
            DataColumn(label: Text(AppStrings.cupsLabelShort, style: headerStyle)),
          if (showGrams)
            DataColumn(label: Text(AppStrings.gramsLabel, style: headerStyle)),
          DataColumn(label: Text(AppStrings.salesLabelDefinite, style: headerStyle)),
          DataColumn(label: Text(AppStrings.costLabelDefinite, style: headerStyle)),
          DataColumn(label: Text(AppStrings.profitLabelDefinite, style: headerStyle)),
        ],
        rows: rows
            .map(
              (r) => DataRow(
                cells: [
                  DataCell(Text(r.key)),
                  if (showCups) DataCell(Text('${r.cups}')),
                  if (showGrams) DataCell(Text(r.grams.toStringAsFixed(0))),
                  DataCell(Text(r.sales.toStringAsFixed(2))),
                  DataCell(Text(r.cost.toStringAsFixed(2))),
                  DataCell(Text(r.profit.toStringAsFixed(2))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
