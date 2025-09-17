import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../stats/utils/op_day.dart';

enum StatsSpan { third1, third2, third3, month }

final statsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final statsSpanProvider = StateProvider<StatsSpan>((ref) {
  final idx = currentThirdIndex(DateTime.now());
  return [StatsSpan.third1, StatsSpan.third2, StatsSpan.third3][idx];
});

final statsRangeProvider = Provider<({DateTime startUtc, DateTime endUtc})>((
  ref,
) {
  final month = ref.watch(statsMonthProvider);
  final span = ref.watch(statsSpanProvider);
  switch (span) {
    case StatsSpan.month:
      return monthRangeUtc(month);
    case StatsSpan.third1:
      return thirdRangeUtc(month, 0);
    case StatsSpan.third2:
      return thirdRangeUtc(month, 1);
    case StatsSpan.third3:
      return thirdRangeUtc(month, 2);
  }
});
