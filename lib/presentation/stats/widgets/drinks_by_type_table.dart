import 'package:flutter/material.dart';

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
        child: Text('لا توجد بيانات مشروبات ضمن الفترة المختارة'),
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
          DataColumn(label: Text('الاسم')),
          DataColumn(label: Text('أكواب')),
          DataColumn(label: Text('المبيعات')),
          DataColumn(label: Text('التكلفة')),
          DataColumn(label: Text('الربح')),
          DataColumn(label: Text('متوسط/كوب')),
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
