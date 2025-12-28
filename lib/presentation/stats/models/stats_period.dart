import 'package:flutter/material.dart';

enum StatsPeriod { firstThird, secondThird, thirdThird, fullMonth }

DateTime defaultStatsMonth([DateTime? now]) {
  final d = now ?? DateTime.now();
  return DateTime(d.year, d.month, 1);
}

StatsPeriod defaultStatsPeriod([DateTime? now]) {
  final d = now ?? DateTime.now();
  if (d.day <= 10) return StatsPeriod.firstThird;
  if (d.day <= 20) return StatsPeriod.secondThird;
  return StatsPeriod.thirdThird;
}

/// ???? ??? UTC ????? ???????? 4 ? – 4 ?
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
        end: DateTime(y, m, 11, 4), // ????
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
