DateTime _at4Local(int y, int m, int d) => DateTime(y, m, d, 4);

({DateTime startUtc, DateTime endUtc}) monthRangeUtc(DateTime monthLocal) {
  final startLocal = _at4Local(monthLocal.year, monthLocal.month, 1);
  final endLocal = _at4Local(monthLocal.year, monthLocal.month + 1, 1);
  return (startUtc: startLocal.toUtc(), endUtc: endLocal.toUtc());
}

({DateTime startUtc, DateTime endUtc}) thirdRangeUtc(
  DateTime monthLocal,
  int idx,
) {
  late DateTime startLocal, endLocal;
  if (idx == 0) {
    // 1..10
    startLocal = _at4Local(monthLocal.year, monthLocal.month, 1);
    endLocal = _at4Local(monthLocal.year, monthLocal.month, 11);
  } else if (idx == 1) {
    // 11..20
    startLocal = _at4Local(monthLocal.year, monthLocal.month, 11);
    endLocal = _at4Local(monthLocal.year, monthLocal.month, 21);
  } else {
    // 21..نهاية الشهر
    startLocal = _at4Local(monthLocal.year, monthLocal.month, 21);
    endLocal = _at4Local(monthLocal.year, monthLocal.month + 1, 1);
  }
  return (startUtc: startLocal.toUtc(), endUtc: endLocal.toUtc());
}

int currentThirdIndex(DateTime nowLocal) {
  final d = nowLocal.day;
  if (d <= 10) return 0;
  if (d <= 20) return 1;
  return 2;
}

/// بداية يوم التشغيل 4 ص (UTC) للترندات
DateTime opDayKeyUtc(DateTime createdUtc) {
  final shifted = createdUtc.subtract(const Duration(hours: 4));
  return DateTime.utc(shifted.year, shifted.month, shifted.day, 4);
}
