import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/stocktake/models/stocktake_models.dart';
import 'package:flutter/material.dart';

class StocktakeRecordCard extends StatelessWidget {
  final StocktakeItem item;
  final TextEditingController controller;
  final String currentText;
  final String diffText;
  final Color diffColor;
  final ValueChanged<String> onChanged;

  const StocktakeRecordCard({
    super.key,
    required this.item,
    required this.controller,
    required this.currentText,
    required this.diffText,
    required this.diffColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(currentText, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              onChanged: onChanged,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                labelText: item.isExtra
                    ? AppStrings.stocktakeCountedLabelUnits
                    : AppStrings.stocktakeCountedLabelKg,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  AppStrings.stocktakeDiffLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  diffText,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: diffColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StocktakeSessionCard extends StatelessWidget {
  final String dateLabel;
  final int totalLines;
  final bool overwrite;
  final VoidCallback onOpen;

  const StocktakeSessionCard({
    super.key,
    required this.dateLabel,
    required this.totalLines,
    required this.overwrite,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _InfoChip('${AppStrings.totalLabel}: $totalLines'),
                _InfoChip(
                  '${AppStrings.stocktakeOverwrite}: ${overwrite ? 'ON' : 'OFF'}',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: const Text(AppStrings.actionOpen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StocktakeLineCard extends StatelessWidget {
  final String title;
  final String beforeText;
  final String countedText;
  final String countedLabel;
  final String diffText;
  final Color diffColor;

  const StocktakeLineCard({
    super.key,
    required this.title,
    required this.beforeText,
    required this.countedText,
    required this.countedLabel,
    required this.diffText,
    required this.diffColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _InfoChip('${AppStrings.stockLabel}: $beforeText'),
                _InfoChip('$countedLabel: $countedText'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${AppStrings.stocktakeDiffLabel}: $diffText',
              style: TextStyle(fontWeight: FontWeight.w800, color: diffColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
