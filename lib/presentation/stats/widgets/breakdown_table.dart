import 'package:flutter/material.dart';
import '../state/stats_data_provider.dart';

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
            label: Text('النوع', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (showCups) DataColumn(label: Text('أكواب', style: headerStyle)),
          if (showGrams) DataColumn(label: Text('جرامات', style: headerStyle)),
          DataColumn(label: Text('المبيعات', style: headerStyle)),
          DataColumn(label: Text('التكلفة', style: headerStyle)),
          DataColumn(label: Text('الربح', style: headerStyle)),
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
