import 'package:flutter/material.dart';

class DrinksBreakdownTable extends StatelessWidget {
  final List<dynamic> list;
  const DrinksBreakdownTable({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('النوع')),
          DataColumn(label: Text('أكواب')),
          DataColumn(label: Text('مبيعات')),
          DataColumn(label: Text('تكلفة')),
          DataColumn(label: Text('ربح')),
          DataColumn(label: Text('متوسط سعر')),
        ],
        rows: list.map((e) => DataRow(cells: [
          DataCell(Text('${e.type}')),
          DataCell(Text('${e.cups}')),
          DataCell(Text('${(e.sales as num).toStringAsFixed(2)}')),
          DataCell(Text('${(e.cost as num).toStringAsFixed(2)}')),
          DataCell(Text('${(e.profit as num).toStringAsFixed(2)}')),
          DataCell(Text('${(e.avgPrice as num).toStringAsFixed(2)}')),
        ])).toList(),
      ),
    );
  }
}