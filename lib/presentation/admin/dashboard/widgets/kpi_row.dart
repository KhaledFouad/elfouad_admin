import 'package:flutter/material.dart';

class KpiRow extends StatelessWidget {
  final dynamic data;
  const KpiRow({super.key, required this.data});

  Widget _k(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _k('إجمالي المبيعات', (data.sales as num).toStringAsFixed(2)),
      _k('التكلفة', (data.cost as num).toStringAsFixed(2)),
      _k('الربح', (data.profit as num).toStringAsFixed(2)),
      _k('الأكواب', (data.cups as int).toString()),
      _k('جرامات البن', (data.grams as num).toStringAsFixed(0)),
      _k('نسبة الضيافة %', (data.complimentaryValuePct as num).toStringAsFixed(1)),
    ];

    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < 700;
      if (isMobile) {
        return Column(
          children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
        );
      }
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.2,
        children: items,
      );
    });
  }
}