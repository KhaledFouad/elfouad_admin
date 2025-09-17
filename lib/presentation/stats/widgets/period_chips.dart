import 'package:flutter/material.dart';

enum StatsPeriod { third1, third2, third3, month }

class PeriodChips extends StatelessWidget {
  final DateTime forMonth; // أي تاريخ داخل الشهر المطلوب
  final StatsPeriod selected;
  final ValueChanged<DateTimeRange> onRangeChange;
  final ValueChanged<StatsPeriod>? onSelected;

  const PeriodChips({
    super.key,
    required this.forMonth,
    required this.selected,
    required this.onRangeChange,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final thirds = _thirdsOfMonth(forMonth);
    final labels = const {
      StatsPeriod.third1: 'الثلث الأول',
      StatsPeriod.third2: 'الثلث الثاني',
      StatsPeriod.third3: 'الثلث الثالث',
      StatsPeriod.month: 'الشهر',
    };

    // شِبس صغيرة وتحت الـAppBar
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: StatsPeriod.values.map((p) {
          final selectedNow = p == selected;
          return ChoiceChip(
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(vertical: -2, horizontal: -2),
            label: Text(labels[p]!),
            selected: selectedNow,
            onSelected: (_) {
              onSelected?.call(p);
              onRangeChange(thirds[p]!);
            },
          );
        }).toList(),
      ),
    );
  }

  /// يقسم الشهر إلى 3 أثلاث: 1..10 ، 11..20 ، والباقي (10 أو 11 حسب طول الشهر)
  Map<StatsPeriod, DateTimeRange> _thirdsOfMonth(DateTime anyDayInMonth) {
    final y = anyDayInMonth.year;
    final m = anyDayInMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(y, m);

    final startMonth = DateTime(y, m, 1, 4); // 4 الفجر كبداية تشغيل
    final d10 = DateTime(y, m, 10, 4);
    final d11 = DateTime(y, m, 11, 4);
    final d20 = DateTime(y, m, 20, 4);
    final d21 = DateTime(y, m, 21, 4);
    final endMonth = DateTime(
      y,
      m,
      daysInMonth,
      4,
    ).add(const Duration(days: 1));

    final third1 = DateTimeRange(start: startMonth, end: d11);
    final third2 = DateTimeRange(start: d11, end: d21);
    final third3 = DateTimeRange(start: d21, end: endMonth);
    final full = DateTimeRange(start: startMonth, end: endMonth);

    return {
      StatsPeriod.third1: third1,
      StatsPeriod.third2: third2,
      StatsPeriod.third3: third3,
      StatsPeriod.month: full,
    };
  }
}
