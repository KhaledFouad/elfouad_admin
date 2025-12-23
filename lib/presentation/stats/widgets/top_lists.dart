import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import '../state/stats_data_provider.dart';

class Top5List extends StatelessWidget {
  final String titleLeft, unitLeft, titleRight, unitRight;
  final List<GroupRow> leftRows, rightRows;
  const Top5List({
    super.key,
    required this.titleLeft,
    required this.unitLeft,
    required this.titleRight,
    required this.unitRight,
    required this.leftRows,
    required this.rightRows,
  });

  @override
  Widget build(BuildContext context) {
    Widget col(String title, String unit, List<GroupRow> rows) {
      return Expanded(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.topFiveTitle(title),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...rows.map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(r.key, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Text(_val(unit, r)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        col(titleLeft, unitLeft, leftRows),
        const SizedBox(width: 12),
        col(titleRight, unitRight, rightRows),
      ],
    );
  }

  String _val(String unit, GroupRow r) {
    switch (unit) {
      case 'cups':
        return r.cups.toString();
      case 'g':
        return r.grams.toStringAsFixed(0);
      case 'profit':
        return r.profit.toStringAsFixed(2);
      case 'sales':
        return r.sales.toStringAsFixed(2);
    }
    return '';
  }
}
