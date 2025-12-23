import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import '../state/stats_period.dart';
import '../state/stats_data_provider.dart'; // علشان preview

class PeriodChips extends ConsumerWidget {
  const PeriodChips({
    super.key,
    required this.forMonth,
    required this.selected,
    required this.onSelected,
    required Null Function(dynamic _) onRangeChange,
  });

  final DateTime forMonth;
  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مجرد قراءة عشان نحسب preview للأثلاث
    final preview = ref.watch(statsThirdsPreviewProvider);

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
        preview.whenData((v) {
          final k = switch (p) {
            StatsPeriod.firstThird => v.third1,
            StatsPeriod.secondThird => v.third2,
            StatsPeriod.thirdThird => v.third3,
            StatsPeriod.fullMonth => v.month,
          };
          trailing = k.sales.toStringAsFixed(0); // ممكن تخليها cups/grams.. الخ
        });

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
