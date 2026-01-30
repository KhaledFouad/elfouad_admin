import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

class TurkishRow {
  final String name;
  final int cups;
  final int plainCups;
  final int spicedCups;
  final double sales;
  final double cost;
  const TurkishRow({
    required this.name,
    required this.cups,
    required this.plainCups,
    required this.spicedCups,
    required this.sales,
    required this.cost,
  });

  double get profit => sales - cost;
}

class TurkishCoffeeTable extends StatelessWidget {
  final List<TurkishRow> rows;
  const TurkishCoffeeTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text(AppStrings.noDataForRange));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        columns: const [
          DataColumn(label: Text(AppStrings.itemLabel)),
          DataColumn(label: Text(AppStrings.cupsLabelShort)),
          DataColumn(label: Text(AppStrings.plainLabel)),
          DataColumn(label: Text(AppStrings.spicedLabelPlain)),
          DataColumn(label: Text(AppStrings.salesLabelDefinite)),
          DataColumn(label: Text(AppStrings.costLabelDefinite)),
          DataColumn(label: Text(AppStrings.profitLabelDefinite)),
        ],
        rows: rows.map((r) {
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 180,
                  child: Text(r.name, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(Text(r.cups.toString())),
              DataCell(Text(r.plainCups.toString())),
              DataCell(Text(r.spicedCups.toString())),
              DataCell(Text(r.sales.toStringAsFixed(2))),
              DataCell(Text(r.cost.toStringAsFixed(2))),
              DataCell(Text(r.profit.toStringAsFixed(2))),
            ],
          );
        }).toList(),
      ),
    );
  }
}
