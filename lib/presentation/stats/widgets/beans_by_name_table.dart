import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

class BeanRow {
  final String name; // name أو name - variant
  final double grams;
  final double plainGrams;
  final double spicedGrams;
  final double sales;
  final double cost;
  BeanRow({
    required this.name,
    required this.grams,
    required this.plainGrams,
    required this.spicedGrams,
    required this.sales,
    required this.cost,
  });
  double get profit => sales - cost;
  double get avgPerKg => grams > 0 ? (sales / grams) * 1000 : 0.0;
}

class BeansByNameTable extends StatelessWidget {
  final List<BeanRow> rows;
  const BeansByNameTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text(AppStrings.noBeansData));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        columns: const [
          DataColumn(label: Text(AppStrings.itemLabel)),
          DataColumn(label: Text(AppStrings.gramsLabel)),
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
              DataCell(Text(r.grams.toStringAsFixed(0))),
              DataCell(Text(r.plainGrams.toStringAsFixed(0))),
              DataCell(Text(r.spicedGrams.toStringAsFixed(0))),
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
