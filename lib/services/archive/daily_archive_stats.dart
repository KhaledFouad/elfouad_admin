import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elfouad_admin/presentation/stats/utils/op_day.dart';
import 'package:elfouad_admin/presentation/stats/utils/stats_data_provider.dart';

const String _dailyArchivePrefKey = 'archive_daily_last_sync';

Future<void> syncDailyArchiveStats({
  FirebaseFirestore? firestore,
  SharedPreferences? prefs,
  int maxBackfillDays = 31,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final localPrefs = prefs ?? await SharedPreferences.getInstance();

  final now = DateTime.now();
  final todayStartLocal = opStartLocal(now);
  final todayKey = opDayKeyFromLocal(now);

  final lastKey = localPrefs.getString(_dailyArchivePrefKey);
  final lastDay = _parseDayKey(lastKey);

  DateTime startLocal;
  if (lastDay == null) {
    startLocal = todayStartLocal.subtract(const Duration(days: 1));
  } else {
    final lastStart = DateTime(lastDay.year, lastDay.month, lastDay.day, 12);
    startLocal = opStartLocal(lastStart).add(const Duration(days: 1));
  }

  final maxStart = todayStartLocal.subtract(Duration(days: maxBackfillDays));
  if (startLocal.isBefore(maxStart)) {
    startLocal = maxStart;
  }

  if (startLocal.isAfter(todayStartLocal)) {
    await localPrefs.setString(_dailyArchivePrefKey, todayKey);
    return;
  }

  var cursor = startLocal;
  while (!cursor.isAfter(todayStartLocal)) {
    await _syncOneDay(db, cursor);
    cursor = cursor.add(const Duration(days: 1));
  }

  await localPrefs.setString(_dailyArchivePrefKey, todayKey);
}

Future<void> _syncOneDay(FirebaseFirestore db, DateTime dayStartLocal) async {
  final startUtc = dayStartLocal.toUtc();
  final endUtc = dayStartLocal.add(const Duration(days: 1)).toUtc();

  final rawSales = await _fetchSalesRawForDay(db, startUtc, endUtc);
  final prepared = prepareStatsData(rawSales);
  final filtered = filterStatsSales(
    prepared,
    startUtc: startUtc,
    endUtc: endUtc,
  );

  final rawExpenses = await fetchStatsExpenses(
    startUtc: startUtc,
    endUtc: endUtc,
    cacheFirst: true,
  );
  final expenses = filterStatsExpenses(
    rawExpenses,
    startUtc: startUtc,
    endUtc: endUtc,
  );

  final kpis = buildKpis(
    filtered,
    expenses,
    startUtc: startUtc,
    endUtc: endUtc,
  );

  final hasAny = kpis.sales != 0 ||
      kpis.cost != 0 ||
      kpis.profit != 0 ||
      kpis.cups != 0 ||
      kpis.grams != 0 ||
      kpis.units != 0 ||
      kpis.expenses != 0;

  if (!hasAny) return;

  final dayKey = opDayKeyFromLocal(dayStartLocal);
  final year = dayStartLocal.year;
  final monthKey = dayStartLocal.month.toString().padLeft(2, '0');
  final dayNumber = dayStartLocal.day;

  final ref = db
      .collection('archive_daily')
      .doc('$year')
      .collection(monthKey)
      .doc(dayKey);

  await ref.set({
    'dayKey': dayKey,
    'year': year,
    'monthNumber': dayStartLocal.month,
    'dayNumber': dayNumber,
    'startUtc': startUtc.toIso8601String(),
    'endUtc': endUtc.toIso8601String(),
    'sales': kpis.sales,
    'cost': kpis.cost,
    'profit': kpis.profit,
    'grams': kpis.grams,
    'drinks': kpis.cups,
    'snacks': kpis.units,
    'expenses': kpis.expenses,
    'updated_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<List<Map<String, dynamic>>> _fetchSalesRawForDay(
  FirebaseFirestore db,
  DateTime startUtc,
  DateTime endUtc,
) async {
  final startIso = startUtc.toIso8601String();
  final endIso = endUtc.toIso8601String();
  final startMs = startUtc.millisecondsSinceEpoch;
  final endMs = endUtc.millisecondsSinceEpoch;

  final combined = <String, Map<String, dynamic>>{};

  final snap = await _getQuerySnapshot(
    db
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: startUtc)
        .where('created_at', isLessThan: endUtc)
        .orderBy('created_at', descending: false),
  );
  for (final d in snap.docs) {
    final m = d.data();
    m['id'] = d.id;
    combined[d.id] = m;
  }

  try {
    final snapOrig = await _getQuerySnapshot(
      db
          .collection('sales')
          .where('original_created_at', isGreaterThanOrEqualTo: startUtc)
          .where('original_created_at', isLessThan: endUtc)
          .orderBy('original_created_at', descending: false),
    );
    for (final d in snapOrig.docs) {
      final m = d.data();
      m['id'] = d.id;
      combined[d.id] = m;
    }
  } catch (_) {}

  if (combined.isNotEmpty) return combined.values.toList();

  try {
    final snapStr = await _getQuerySnapshot(
      db
          .collection('sales')
          .where('created_at', isGreaterThanOrEqualTo: startIso)
          .where('created_at', isLessThan: endIso)
          .orderBy('created_at', descending: false),
    );
    for (final d in snapStr.docs) {
      final m = d.data();
      m['id'] = d.id;
      combined[d.id] = m;
    }
  } catch (_) {}

  if (combined.isNotEmpty) return combined.values.toList();

  try {
    final snapNum = await _getQuerySnapshot(
      db
          .collection('sales')
          .where('created_at', isGreaterThanOrEqualTo: startMs)
          .where('created_at', isLessThan: endMs)
          .orderBy('created_at', descending: false),
    );
    for (final d in snapNum.docs) {
      final m = d.data();
      m['id'] = d.id;
      combined[d.id] = m;
    }
  } catch (_) {}

  return combined.values.toList();
}

Future<QuerySnapshot<Map<String, dynamic>>> _getQuerySnapshot(
  Query<Map<String, dynamic>> query,
) async {
  try {
    final cached = await query.get(const GetOptions(source: Source.cache));
    if (cached.docs.isNotEmpty) return cached;
  } catch (_) {}
  return query.get();
}

DateTime? _parseDayKey(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (match == null) return null;
  final y = int.tryParse(match.group(1) ?? '');
  final m = int.tryParse(match.group(2) ?? '');
  final d = int.tryParse(match.group(3) ?? '');
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}
