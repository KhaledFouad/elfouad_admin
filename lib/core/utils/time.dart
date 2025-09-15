class DateTimeRangeUtc {
  final DateTime startUtc;
  final DateTime endUtc;
  DateTimeRangeUtc(this.startUtc, this.endUtc);
}

class OpTime {
  /// Current operational day (4AM -> 4AM) based on local time, returned as UTC bounds.
  static (DateTime, DateTime) todayOperationalRangeUtc() {
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day, 4);
    final endLocal = startLocal.add(const Duration(days: 1));
    return (startLocal.toUtc(), endLocal.toUtc());
  }

  /// Maps a UTC timestamp to the 4AM-anchored operational day key (UTC 04:00).
  static DateTime opDayKeyUtc(DateTime createdUtc) {
    final shifted = createdUtc.subtract(const Duration(hours: 4));
    return DateTime.utc(shifted.year, shifted.month, shifted.day, 4);
  }
}