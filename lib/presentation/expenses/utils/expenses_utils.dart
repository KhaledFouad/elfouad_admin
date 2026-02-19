import 'package:flutter/material.dart';

const kDarkBrown = Color(0xFF543824);
const kBeige = Color(0xFFC49A6C);

/// Operational day starts at 4 AM local.
DateTimeRange todayOperationalRangeLocal() {
  final now = DateTime.now();
  final today4 = DateTime(now.year, now.month, now.day, 4);
  final start = now.isBefore(today4)
      ? today4.subtract(const Duration(days: 1))
      : today4;
  final end = start.add(const Duration(days: 1));
  return DateTimeRange(start: start, end: end);
}
