import 'package:elfouad_admin/presentation/inventory/providers.dart';
import 'package:flutter/material.dart';

class InventoryTile extends StatelessWidget {
  final InventoryRow row;
  // final VoidCallback? onEdit;
  // final VoidCallback? onDelete;
  final double maxStockForBar;
  const InventoryTile({
    super.key,
    required this.row,
    required this.maxStockForBar,
    // this.onEdit,
    // this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = row.variant.isEmpty
        ? row.name
        : '${row.name} — ${row.variant}';
    final percent = (row.stockG / (maxStockForBar <= 0 ? 1 : maxStockForBar))
        .clamp(0.0, 1.0);

    Color barColor;
    if (row.stockG <= row.minLevelG && row.minLevelG > 0) {
      barColor = Colors.red.shade400;
    } else if (row.stockG <= 2500) {
      // 2.5 كجم تحذيري
      barColor = Colors.orange.shade500;
    } else {
      barColor = const Color(0xFF6F4E37); // بني
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان + أزرار
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // if (onDelete != null)
                //   IconButton(
                //     icon: const Icon(Icons.delete_outline),
                //     onPressed: onDelete,
                //     tooltip: 'حذف',
                //   ),
                // if (onEdit != null)
                //   IconButton(
                //     icon: const Icon(Icons.edit),
                //     onPressed: onEdit,
                //     tooltip: 'تعديل',
                //   ),
              ],
            ),
            const SizedBox(height: 4),
            // معلومات سطر واحد
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _chip(
                  Icons.scale,
                  'مخزون',
                  '${row.stockG.toStringAsFixed(0)} جم',
                ),
                _chip(Icons.sell, 'سعر/كجم', row.sellPerKg.toStringAsFixed(2)),
                if (row.minLevelG > 0)
                  _chip(
                    Icons.warning_amber_rounded,
                    'حد أدنى',
                    '${row.minLevelG.toStringAsFixed(0)} جم',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // شريط التقدم للمخزون
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                backgroundColor: Colors.brown.shade50,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData i, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 16),
          const SizedBox(width: 6),
          Text(
            '$k: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
