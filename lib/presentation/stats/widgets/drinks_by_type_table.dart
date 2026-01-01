import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

class DrinkRow {
  final String name;
  final int cups;
  final double sales, cost, profit, avgPrice;
  const DrinkRow({
    required this.name,
    required this.cups,
    required this.sales,
    required this.cost,
    required this.profit,
    required this.avgPrice,
  });
}

class DrinksByNameTable extends StatelessWidget {
  final List<DrinkRow> rows;
  const DrinksByNameTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(AppStrings.noDrinksData),
      );
    }

    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 390;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        columns: const [
          DataColumn(label: Text(AppStrings.nameLabel)),
          DataColumn(label: Text(AppStrings.cupsLabelShort)),
          DataColumn(label: Text(AppStrings.salesLabelDefinite)),
          DataColumn(label: Text(AppStrings.costLabelDefinite)),
          DataColumn(label: Text(AppStrings.profitLabelDefinite)),
          DataColumn(label: Text(AppStrings.averagePerCupLabel)),
        ],
        rows: rows.map((r) {
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: isWide ? 180 : 140,
                  child: Text(r.name, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(Text(r.cups.toString())),
              DataCell(Text(r.sales.toStringAsFixed(2))),
              DataCell(Text(r.cost.toStringAsFixed(2))),
              DataCell(Text(r.profit.toStringAsFixed(2))),
              DataCell(Text(r.avgPrice.toStringAsFixed(2))),
            ],
          );
        }).toList(),
      ),
    );
  }
}
