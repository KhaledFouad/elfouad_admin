import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds the chosen DateTimeRange (4am-4am).
class DateRangeCubit extends Cubit<DateTimeRange> {
  DateRangeCubit() : super(_todayRange4amLocal());

  /// Public: set a specific range (already aligned to 4am).
  void setRange(DateTimeRange? range) =>
      emit(range ?? _todayRange4amLocal());

  /// Public: clear to "today operational".
  void clear() => emit(_todayRange4amLocal());

  /// Compute 4am-4am range for today based on local time.
  static DateTimeRange today() => _todayRange4amLocal();
}

/// ==== helpers (local to this file) ====
DateTimeRange _todayRange4amLocal() {
  final now = DateTime.now();
  final today4am = DateTime(now.year, now.month, now.day, 4);

  late DateTime startLocal;
  late DateTime endLocal;
  if (now.isBefore(today4am)) {
    startLocal = today4am.subtract(const Duration(days: 1));
    endLocal = today4am;
  } else {
    startLocal = today4am;
    endLocal = today4am.add(const Duration(days: 1));
  }
  return DateTimeRange(start: startLocal, end: endLocal);
}
