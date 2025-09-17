import 'package:flutter/material.dart';

class BeansBreakdownTable extends StatelessWidget {
  final List<dynamic> list;
  const BeansBreakdownTable({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('العائلة/المنشأ')),
          DataColumn(label: Text('جرامات')),
          DataColumn(label: Text('مبيعات')),
          DataColumn(label: Text('تكلفة')),
          DataColumn(label: Text('ربح')),
          DataColumn(label: Text('متوسط/كجم')),
        ],
        rows: list
            .map(
              (e) => DataRow(
                cells: [
                  DataCell(Text('${e.family}')),
                  DataCell(Text((e.grams as num).toStringAsFixed(0))),
                  DataCell(Text((e.sales as num).toStringAsFixed(2))),
                  DataCell(Text((e.cost as num).toStringAsFixed(2))),
                  DataCell(Text((e.profit as num).toStringAsFixed(2))),
                  DataCell(Text((e.avgPerKg as num).toStringAsFixed(2))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
