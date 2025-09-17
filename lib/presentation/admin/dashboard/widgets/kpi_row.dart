import 'package:flutter/material.dart';

class KpiRow extends StatelessWidget {
  final dynamic data;
  const KpiRow({super.key, required this.data});

  Widget _k(BuildContext context, String title, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _k(context, 'إجمالي المبيعات', (data.sales as num).toStringAsFixed(2), Icons.attach_money),
      _k(context, 'التكلفة', (data.cost as num).toStringAsFixed(2), Icons.factory),
      _k(context, 'الربح', (data.profit as num).toStringAsFixed(2), Icons.trending_up),
      _k(context, 'الأكواب', (data.cups as int).toString(), Icons.local_cafe),
      _k(context, 'جرامات البن', (data.grams as num).toStringAsFixed(0), Icons.scale),
      _k(context, 'نسبة الضيافة %', (data.complimentaryValuePct as num).toStringAsFixed(1), Icons.volunteer_activism),
    ];

    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < 720;
      if (isMobile) {
        return Column(
          children: items.map((w)=>Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
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