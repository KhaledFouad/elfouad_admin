import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// تقسيم الإحصائيات
enum StatsPeriod { firstThird, secondThird, thirdThird, fullMonth }

/// الشهر المعروض (افتراضي: الشهر الحالي)
final statsForMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1); // أول يوم في الشهر (محلي)
});

/// الثلث الافتراضي: الثلث الذي أنت فيه الآن
final statsSelectedPeriodProvider = StateProvider<StatsPeriod>((ref) {
  final d = DateTime.now().day;
  if (d <= 10) return StatsPeriod.firstThird;
  if (d <= 20) return StatsPeriod.secondThird;
  return StatsPeriod.thirdThird;
});

/// يحسب مدى UTC لليوم التشغيلي 4 ص → 4 ص
({DateTime startUtc, DateTime endUtc}) statsComputeRange(
  DateTime month,
  StatsPeriod p,
) {
  final y = month.year, m = month.month;
  final dim = DateUtils.getDaysInMonth(y, m);

  late final DateTimeRange local;
  switch (p) {
    case StatsPeriod.firstThird:
      local = DateTimeRange(
        start: DateTime(y, m, 1, 4),
        end: DateTime(y, m, 11, 4), // حصري
      );
      break;
    case StatsPeriod.secondThird:
      local = DateTimeRange(
        start: DateTime(y, m, 11, 4),
        end: DateTime(y, m, 21, 4),
      );
      break;
    case StatsPeriod.thirdThird:
      local = DateTimeRange(
        start: DateTime(y, m, 21, 4),
        end: DateTime(y, m, dim, 4).add(const Duration(days: 1)),
      );
      break;
    case StatsPeriod.fullMonth:
      local = DateTimeRange(
        start: DateTime(y, m, 1, 4),
        end: DateTime(y, m, dim, 4).add(const Duration(days: 1)),
      );
      break;
  }
  return (startUtc: local.start.toUtc(), endUtc: local.end.toUtc());
}

/// مزوّد المدى النهائي المعتمد في كل الاستعلامات
final statsRangeProvider = Provider<({DateTime startUtc, DateTime endUtc})>((
  ref,
) {
  final month = ref.watch(statsForMonthProvider);
  final p = ref.watch(statsSelectedPeriodProvider);
  return statsComputeRange(month, p);
});
