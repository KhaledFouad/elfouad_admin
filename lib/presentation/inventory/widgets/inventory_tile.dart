import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/models/extra_inventory_row.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';

class InventoryTile extends StatelessWidget {
  final String title;
  final List<_InventoryChipData> _chips;
  final double? progressValue;
  final Color? progressColor;

  const InventoryTile._({
    super.key,
    required this.title,
    required List<_InventoryChipData> chips,
    this.progressValue,
    this.progressColor,
  }) : _chips = chips;

  factory InventoryTile.coffee({
    Key? key,
    required InventoryRow row,
    required double maxStockForBar,
  }) {
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

    return InventoryTile._(
      key: key,
      title: title,
      chips: [
        _InventoryChipData(
          icon: Icons.scale,
          label: AppStrings.stockLabel,
          value: AppStrings.gramsAmount(row.stockG),
        ),
        _InventoryChipData(
          icon: Icons.sell,
          label: AppStrings.pricePerKgLabel,
          value: row.sellPerKg.toStringAsFixed(2),
        ),
        if (row.minLevelG > 0)
          _InventoryChipData(
            icon: Icons.warning_amber_rounded,
            label: AppStrings.minLevelLabel,
            value: AppStrings.gramsAmount(row.minLevelG),
          ),
      ],
      progressValue: percent,
      progressColor: barColor,
    );
  }

  factory InventoryTile.extra({
    Key? key,
    required ExtraInventoryRow row,
    bool showStock = true,
  }) {
    final subtitle = row.category.trim();
    final title = subtitle.isEmpty ? row.name : '${row.name} — $subtitle';

    final chips = <_InventoryChipData>[
      if (showStock)
        _InventoryChipData(
          icon: Icons.scale,
          label: AppStrings.stockLabel,
          value: _formatStock(row.stockUnits, row.unit),
        ),
      _InventoryChipData(
        icon: Icons.sell,
        label: AppStrings.pricePerUnitLabel,
        value: _formatNumber(row.priceSell),
      ),
      _InventoryChipData(
        icon: Icons.money_off,
        label: AppStrings.costPerUnitLabel,
        value: _formatNumber(row.costUnit),
      ),
      if (!row.active)
        _InventoryChipData(
          icon: Icons.pause_circle_filled,
          label: AppStrings.statusLabel,
          value: AppStrings.inactiveLabel,
        ),
    ];

    return InventoryTile._(key: key, title: title, chips: chips);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: _chips
                  .map((c) => _chip(c.icon, c.label, c.value))
                  .toList(),
            ),
            if (progressValue != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressValue!.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.brown.shade50,
                  valueColor: AlwaysStoppedAnimation(
                    progressColor ?? const Color(0xFF6F4E37),
                  ),
                ),
              ),
            ],
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

  static String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static String _formatStock(double stock, String unit) {
    final formatted = _formatNumber(stock);
    final trimmedUnit = unit.trim();
    if (trimmedUnit.isEmpty) return formatted;
    return '$formatted $trimmedUnit';
  }
}

class _InventoryChipData {
  final IconData icon;
  final String label;
  final String value;

  const _InventoryChipData({
    required this.icon,
    required this.label,
    required this.value,
  });
}
