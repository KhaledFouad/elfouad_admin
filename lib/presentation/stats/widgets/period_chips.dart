import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/presentation/stats/state/stats_data_provider.dart';
import 'package:elfouad_admin/presentation/stats/state/stats_period.dart';
import 'package:flutter/material.dart';

class PeriodChips extends StatelessWidget {
  const PeriodChips({
    super.key,
    required this.forMonth,
    required this.selected,
    required this.preview,
    required this.onSelected,
  });

  final DateTime forMonth;
  final StatsPeriod selected;
  final ThirdsPreview? preview;
  final ValueChanged<StatsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(StatsPeriod, String)>[
      (StatsPeriod.firstThird, AppStrings.firstThirdLabel),
      (StatsPeriod.secondThird, AppStrings.secondThirdLabel),
      (StatsPeriod.thirdThird, AppStrings.thirdThirdLabel),
      (StatsPeriod.fullMonth, AppStrings.fullMonthLabel),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        final p = e.$1;
        final label = e.$2;

        String trailing = '';
        if (preview != null) {
          final k = switch (p) {
            StatsPeriod.firstThird => preview!.firstThird,
            StatsPeriod.secondThird => preview!.secondThird,
            StatsPeriod.thirdThird => preview!.thirdThird,
            StatsPeriod.fullMonth => preview!.month,
          };
          trailing = k.sales.toStringAsFixed(0);
        }

        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (trailing.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  trailing,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
          selected: selected == p,
          onSelected: (_) => onSelected(p),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        );
      }).toList(),
    );
  }
}
