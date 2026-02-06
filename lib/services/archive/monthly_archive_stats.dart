import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elfouad_admin/services/archive/daily_archive_stats.dart'
    show backfillDailyArchiveForMonth;

const String _monthlyArchivePrefKey = 'archive_monthly_last_sync';
const String _monthlyArchiveBackfillKey = 'archive_monthly_backfill_done';
const String _monthlyArchiveCollection = 'archive_months';

Future<void> syncMonthlyArchiveStats({
  FirebaseFirestore? firestore,
  SharedPreferences? prefs,
  int maxBackfillMonths = 12,
  int refreshRecentMonths = 2,
  bool includeCurrentMonth = false,
  bool force = false,
  bool backfillAllIfNeeded = true,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final localPrefs = prefs ?? await SharedPreferences.getInstance();

  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month, 1);
  final lastKey = localPrefs.getString(_monthlyArchivePrefKey);
  final lastMonth = _parseMonthKey(lastKey);
  final backfillDone = localPrefs.getBool(_monthlyArchiveBackfillKey) ?? false;
  final shouldBackfillAll = backfillAllIfNeeded && !backfillDone;

  final minStart = DateTime(now.year, now.month - maxBackfillMonths + 1, 1);
  DateTime startMonth;

  if (shouldBackfillAll) {
    startMonth = await _findArchiveStartMonth(db) ?? minStart;
    force = true;
  } else if (force) {
    startMonth = await _findArchiveStartMonth(db) ?? minStart;
  } else if (lastMonth == null) {
    startMonth = minStart;
  } else {
    final back = refreshRecentMonths > 1 ? refreshRecentMonths - 1 : 0;
    startMonth = DateTime(lastMonth.year, lastMonth.month - back, 1);
    if (startMonth.isBefore(minStart)) startMonth = minStart;
  }

  final endMonth = includeCurrentMonth
      ? currentMonth
      : DateTime(currentMonth.year, currentMonth.month - 1, 1);

  if (startMonth.isAfter(endMonth)) {
    await localPrefs.setString(_monthlyArchivePrefKey, _monthKey(endMonth));
    return;
  }

  final refreshCutoff = DateTime(
    endMonth.year,
    endMonth.month - (refreshRecentMonths - 1),
    1,
  );

  var cursor = startMonth;
  while (!cursor.isAfter(endMonth)) {
    final shouldRefresh =
        force || !cursor.isBefore(refreshCutoff) || cursor == endMonth;
    await _syncOneMonth(db, cursor, refresh: shouldRefresh);
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  if (shouldBackfillAll) {
    await localPrefs.setBool(_monthlyArchiveBackfillKey, true);
  }
  await localPrefs.setString(_monthlyArchivePrefKey, _monthKey(endMonth));
}

Future<void> syncMonthlyArchiveForMonth({
  FirebaseFirestore? firestore,
  required DateTime month,
  bool force = true,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final target = DateTime(month.year, month.month, 1);
  await _syncOneMonth(db, target, refresh: force);
}

Future<void> _syncOneMonth(
  FirebaseFirestore db,
  DateTime month, {
  required bool refresh,
}) async {
  final key = _monthKey(month);
  final docRef = db.collection(_monthlyArchiveCollection).doc(key);

  if (!refresh) {
    final existing = await docRef.get();
    if (existing.exists) return;
  }

  if (_isCurrentOrPreviousMonth(month, DateTime.now())) {
    await backfillDailyArchiveForMonth(
      firestore: db,
      month: month,
      includeLiveSales: true,
    );
  }

  final data = await _buildMonthlyFromDaily(db, month);
  if (data == null || data.isEmpty) return;
  await docRef.set(data, SetOptions(merge: true));
}

bool _isCurrentOrPreviousMonth(DateTime month, DateTime now) {
  final current = DateTime(now.year, now.month, 1);
  final previous = DateTime(now.year, now.month - 1, 1);
  final target = DateTime(month.year, month.month, 1);
  return (target.year == current.year && target.month == current.month) ||
      (target.year == previous.year && target.month == previous.month);
}

Future<Map<String, dynamic>?> _buildMonthlyFromDaily(
  FirebaseFirestore db,
  DateTime month,
) async {
  final year = month.year;
  final monthKey = month.month.toString().padLeft(2, '0');
  final dailyRef = db
      .collection('archive_daily')
      .doc('$year')
      .collection(monthKey);

  QuerySnapshot<Map<String, dynamic>> snap;
  try {
    snap = await dailyRef.get();
  } catch (_) {
    return null;
  }
  if (snap.docs.isEmpty) return null;

  double sales = 0, cost = 0, profit = 0, grams = 0, expenses = 0;
  int cups = 0, units = 0, orders = 0;
  final days = <Map<String, dynamic>>[];

  for (final doc in snap.docs) {
    final day = _normalizeDay(doc.id, doc.data(), month);
    days.add(day);

    sales += _num(day['sales']);
    cost += _num(day['cost']);
    profit += _num(day['profit']);
    grams += _num(day['grams']);
    expenses += _num(day['expenses']);
    cups += _int(day['cups'] ?? day['drinks']);
    units += _int(day['units'] ?? day['snacks']);
    orders += _int(day['orders']);
  }

  days.sort(
    (a, b) =>
        (a['dayKey'] ?? '').toString().compareTo((b['dayKey'] ?? '').toString()),
  );

  final monthId = _monthKey(month);
  return {
    'summary': {
      'sales': sales,
      'cost': cost,
      'profit': profit,
      'grams': grams,
      'cups': cups,
      'drinks': cups,
      'units': units,
      'snacks': units,
      'expenses': expenses,
      'orders': orders,
    },
    'days': days,
    'daysCount': days.length,
    'year': year,
    'monthNumber': month.month,
    'monthKey': monthId,
    'source': 'archive_daily_rollup',
    'updated_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> _normalizeDay(
  String docId,
  Map<String, dynamic> data,
  DateTime month,
) {
  final dayKey = _resolveDayKey(docId, data, month);
  final startFallback =
      DateTime(dayKey.year, dayKey.month, dayKey.day, 4).toUtc().toIso8601String();
  final endFallback = DateTime(dayKey.year, dayKey.month, dayKey.day, 4)
      .add(const Duration(days: 1))
      .toUtc()
      .toIso8601String();

  return {
    'dayKey': _dayKeyString(dayKey),
    'year': _int(data['year']) == 0 ? dayKey.year : _int(data['year']),
    'monthNumber': _int(data['monthNumber']) == 0
        ? dayKey.month
        : _int(data['monthNumber']),
    'dayNumber':
        _int(data['dayNumber']) == 0 ? dayKey.day : _int(data['dayNumber']),
    'startUtc': _toIsoUtc(data['startUtc'] ?? data['start_utc'], startFallback),
    'endUtc': _toIsoUtc(data['endUtc'] ?? data['end_utc'], endFallback),
    'sales': _num(data['sales']),
    'cost': _num(data['cost']),
    'profit': _num(data['profit']),
    'grams': _num(data['grams']),
    'cups': _int(data['cups'] ?? data['drinks']),
    'units': _int(data['units'] ?? data['snacks']),
    'drinks': _int(data['cups'] ?? data['drinks']),
    'snacks': _int(data['units'] ?? data['snacks']),
    'expenses': _num(data['expenses']),
    'orders': _int(data['orders']),
    'drinks_rows': _asRowList(data['drinks_rows']),
    'beans_rows': _asRowList(data['beans_rows']),
    'turkish_rows': _asRowList(data['turkish_rows']),
    'extras_rows': _asRowList(data['extras_rows']),
  };
}

DateTime _resolveDayKey(String docId, Map<String, dynamic> data, DateTime month) {
  final raw = (data['dayKey'] ?? docId).toString().trim();
  final parsed = _parseDayKey(raw);
  if (parsed != null) return parsed;
  final dayNumber = _int(data['dayNumber']);
  if (dayNumber > 0 && dayNumber <= 31) {
    return DateTime(month.year, month.month, dayNumber);
  }
  return DateTime(month.year, month.month, 1);
}

String _dayKeyString(DateTime day) {
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '${day.year}-$m-$d';
}

DateTime? _parseDayKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final y = int.tryParse(match.group(1) ?? '');
  final m = int.tryParse(match.group(2) ?? '');
  final d = int.tryParse(match.group(3) ?? '');
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _toIsoUtc(dynamic value, String fallback) {
  final dt = _asDate(value);
  if (dt == null) return fallback;
  return dt.toUtc().toIso8601String();
}

DateTime? _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    final raw = value.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<Map<String, dynamic>> _asRowList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String _monthKey(DateTime month) {
  final m = month.month.toString().padLeft(2, '0');
  return '${month.year}-$m';
}

DateTime? _parseMonthKey(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(trimmed);
  if (match == null) return null;
  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  if (year == null || month == null) return null;
  return DateTime(year, month, 1);
}

Future<DateTime?> _findArchiveStartMonth(FirebaseFirestore db) async {
  try {
    final snap = await db.collection('archive_daily').get();
    if (snap.docs.isEmpty) return null;

    int? minYear;
    for (final doc in snap.docs) {
      final y = int.tryParse(doc.id);
      if (y == null) continue;
      minYear = minYear == null ? y : (y < minYear ? y : minYear);
    }
    if (minYear == null) return null;
    return DateTime(minYear, 1, 1);
  } catch (_) {
    return null;
  }
}
