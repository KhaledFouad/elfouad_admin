import 'package:flutter/material.dart';

class Kpi {
  final String title;
  final String value;
  final IconData icon;
  Kpi(this.title, this.value, this.icon);
}

class KpiWrap extends StatelessWidget {
  final List<Kpi> items;
  const KpiWrap({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // موبايل: كرتين في الصف. لو الشاشة أوسع هتزود تلقائي.
        final w = c.maxWidth;
        final perRow = w < 380 ? 1 : (w < 700 ? 2 : 3);
        final itemWidth = (w - (12 * (perRow - 1))) / perRow;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((k) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: itemWidth,
                maxWidth: itemWidth,
              ),
              child: _KpiCard(k: k),
            );
          }).toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final Kpi k;
  const _KpiCard({required this.k});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.brown.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.brown.shade100,
              child: Icon(k.icon, size: 18, color: Colors.brown.shade700),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.title,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      k.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
