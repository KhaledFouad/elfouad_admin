class DateTimeRangeUtc {
  final DateTime startUtc;
  final DateTime endUtc;
  const DateTimeRangeUtc(this.startUtc, this.endUtc);
}

class OpTime {
  static (DateTime, DateTime) todayOperationalRangeUtc() {
    final now = DateTime.now();
    final today4 = DateTime(now.year, now.month, now.day, 4);
    final startLocal = now.isBefore(today4) ? today4.subtract(const Duration(days: 1)) : today4;
    final endLocal = startLocal.add(const Duration(days: 1));
    return (startLocal.toUtc(), endLocal.toUtc());
  }

  static (DateTime, DateTime) monthOperationalRangeUtc(DateTime anchorLocal) {
    final first = DateTime(anchorLocal.year, anchorLocal.month, 1, 4);
    final nextMonth = (anchorLocal.month == 12)
        ? DateTime(anchorLocal.year + 1, 1, 1, 4)
        : DateTime(anchorLocal.year, anchorLocal.month + 1, 1, 4);
    return (first.toUtc(), nextMonth.toUtc());
  }

  static DateTime opDayKeyUtc(DateTime createdUtc) {
    final shifted = createdUtc.subtract(const Duration(hours: 4));
    return DateTime.utc(shifted.year, shifted.month, shifted.day, 4);
  }
}
