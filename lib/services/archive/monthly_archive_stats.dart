import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elfouad_admin/presentation/stats/models/stats_period.dart';
import 'package:elfouad_admin/presentation/stats/models/stats_models.dart';
import 'package:elfouad_admin/presentation/stats/utils/stats_data_provider.dart';

const String _monthlyArchivePrefKey = 'archive_monthly_last_sync';
const String _monthlyArchiveBackfillKey = 'archive_monthly_backfill_done';
const String _monthlyArchiveCollection = 'archive_months';

const List<String> _summaryDocIds = [
  'summary',
  'totals',
  'kpis',
  'stats',
  'month',
];

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

  final data = await _buildMonthlyFromArchiveSales(db, month);
  if (data == null || data.isEmpty) return;

  await docRef.set(data, SetOptions(merge: true));
}

Future<Map<String, dynamic>?> _buildMonthlyFromArchiveSales(
  FirebaseFirestore db,
  DateTime month,
) async {
  final monthKey = month.month.toString().padLeft(2, '0');
  final coll = db.collection('archive').doc('${month.year}').collection(monthKey);
  final snap = await coll.get();

  final rawById = <String, Map<String, dynamic>>{};
  for (final doc in snap.docs) {
    if (_summaryDocIds.contains(doc.id)) continue;
    final data = doc.data();
    final id = _pickSaleId(data, fallback: doc.id);
    rawById[id] = data;
  }

  // Merge any missing sales from archive_bin to fix partial months.
  final merged = await _mergeArchiveBinSales(
    db,
    month,
    rawById,
  );
  if (merged.isEmpty) {
    final fromBin = await _buildMonthlyFromArchiveBin(db, month);
    if (fromBin != null && fromBin.isNotEmpty) return fromBin;
    return null;
  }
  final raw = merged.values.toList();

  final prepared = prepareStatsData(raw);
  final range = statsComputeRange(month, StatsPeriod.fullMonth);
  final filtered = filterStatsSales(
    prepared,
    startUtc: range.startUtc,
    endUtc: range.endUtc,
  );
  final rawExpenses = await fetchStatsExpenses(
    startUtc: range.startUtc,
    endUtc: range.endUtc,
    cacheFirst: true,
  );
  final expenses = filterStatsExpenses(
    rawExpenses,
    startUtc: range.startUtc,
    endUtc: range.endUtc,
  );
  final kpis = buildKpis(
    filtered,
    expenses,
    startUtc: range.startUtc,
    endUtc: range.endUtc,
  );
  final beansRows = buildBeansRows(
    filtered,
    startUtc: range.startUtc,
    endUtc: range.endUtc,
  );
  final turkishRows = buildTurkishRows(
    filtered,
    startUtc: range.startUtc,
    endUtc: range.endUtc,
  );

  final effectiveProfit = _normalizeProfit(kpis);
  return {
    'summary': {
      'sales': kpis.sales,
      'cost': kpis.cost,
      'profit': effectiveProfit,
      'grams': kpis.grams,
      'drinks': kpis.cups,
      'snacks': kpis.units,
      'expenses': kpis.expenses,
    },
    'beans_rows': beansRows
        .map(
          (r) => {
            'name': r.name,
            'grams': r.grams,
            'plainGrams': r.plainGrams,
            'spicedGrams': r.spicedGrams,
            'sales': r.sales,
            'cost': r.cost,
          },
        )
        .toList(),
    'turkish_rows': turkishRows
        .map(
          (r) {
            final plain = r.plainGrams.round();
            final spiced = r.spicedGrams.round();
            final cups = r.cups > 0 ? r.cups : (plain + spiced);
            return {
              'name': r.name,
              'cups': cups,
              'plainCups': plain,
              'spicedCups': spiced,
              'sales': r.sales,
              'cost': r.cost,
            };
          },
        )
        .toList(),
    'year': month.year,
    'monthNumber': month.month,
    'monthKey': _monthKey(month),
    'source': 'archive_sales',
    'rowsCount': raw.length,
    'updated_at': FieldValue.serverTimestamp(),
  };
}

Future<Map<String, dynamic>?> _buildMonthlyFromArchiveBin(
  FirebaseFirestore db,
  DateTime month,
) async {
  final range = statsComputeRange(month, StatsPeriod.fullMonth);
  final startUtc = range.startUtc;
  final endUtc = range.endUtc;

  final raw = <Map<String, dynamic>>[];
  DocumentSnapshot<Map<String, dynamic>>? last;

  while (true) {
    Query<Map<String, dynamic>> q = db
        .collection('archive_bin')
        .orderBy('archived_at')
        .limit(400);
    if (last != null) q = q.startAfterDocument(last);

    final snap = await q.get();
    if (snap.docs.isEmpty) break;

    for (final doc in snap.docs) {
      final entry = doc.data();
      if (entry['kind']?.toString() != 'sale') continue;
      final dataRaw = entry['data'];
      if (dataRaw is! Map) continue;
      final data = dataRaw.cast<String, dynamic>();
      if (!data.containsKey('created_at') &&
          entry.containsKey('created_at_original')) {
        data['created_at'] = entry['created_at_original'];
      }

      final prepared = prepareStatsData([data]);
      final filtered = filterStatsSales(
        prepared,
        startUtc: startUtc,
        endUtc: endUtc,
      );
      if (filtered.isEmpty) continue;
      raw.addAll(filtered);
    }

    last = snap.docs.last;
  }

  if (raw.isEmpty) return null;

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
    raw,
    expenses,
    startUtc: startUtc,
    endUtc: endUtc,
  );
  final effectiveProfit = _normalizeProfit(kpis);
  final beansRows = buildBeansRows(
    raw,
    startUtc: startUtc,
    endUtc: endUtc,
  );
  final turkishRows = buildTurkishRows(
    raw,
    startUtc: startUtc,
    endUtc: endUtc,
  );

  return {
    'summary': {
      'sales': kpis.sales,
      'cost': kpis.cost,
      'profit': effectiveProfit,
      'grams': kpis.grams,
      'drinks': kpis.cups,
      'snacks': kpis.units,
      'expenses': kpis.expenses,
    },
    'beans_rows': beansRows
        .map(
          (r) => {
            'name': r.name,
            'grams': r.grams,
            'plainGrams': r.plainGrams,
            'spicedGrams': r.spicedGrams,
            'sales': r.sales,
            'cost': r.cost,
          },
        )
        .toList(),
    'turkish_rows': turkishRows
        .map(
          (r) {
            final plain = r.plainGrams.round();
            final spiced = r.spicedGrams.round();
            final cups = r.cups > 0 ? r.cups : (plain + spiced);
  return {
              'name': r.name,
              'cups': cups,
              'plainCups': plain,
              'spicedCups': spiced,
              'sales': r.sales,
              'cost': r.cost,
            };
          },
        )
        .toList(),
    'year': month.year,
    'monthNumber': month.month,
    'monthKey': _monthKey(month),
    'source': 'archive_bin',
    'rowsCount': raw.length,
    'updated_at': FieldValue.serverTimestamp(),
  };
}

Future<Map<String, Map<String, dynamic>>> _mergeArchiveBinSales(
  FirebaseFirestore db,
  DateTime month,
  Map<String, Map<String, dynamic>> base,
) async {
  final range = statsComputeRange(month, StatsPeriod.fullMonth);
  final startUtc = range.startUtc;
  final endUtc = range.endUtc;

  final out = Map<String, Map<String, dynamic>>.from(base);
  DocumentSnapshot<Map<String, dynamic>>? last;

  while (true) {
    Query<Map<String, dynamic>> q = db
        .collection('archive_bin')
        .orderBy('archived_at')
        .limit(400);
    if (last != null) q = q.startAfterDocument(last);

    final snap = await q.get();
    if (snap.docs.isEmpty) break;

    for (final doc in snap.docs) {
      final entry = doc.data();
      if (entry['kind']?.toString() != 'sale') continue;
      final dataRaw = entry['data'];
      if (dataRaw is! Map) continue;
      final data = dataRaw.cast<String, dynamic>();
      if (!data.containsKey('created_at') &&
          entry.containsKey('created_at_original')) {
        data['created_at'] = entry['created_at_original'];
      }

      final prepared = prepareStatsData([data]);
      final filtered = filterStatsSales(
        prepared,
        startUtc: startUtc,
        endUtc: endUtc,
      );
      if (filtered.isEmpty) continue;
      final normalized = filtered.first;
      final id = _pickSaleId(
        normalized,
        fallback: entry['original_id']?.toString() ?? doc.id,
      );
      out.putIfAbsent(id, () => normalized);
    }

    last = snap.docs.last;
  }

  return out;
}

String _pickSaleId(
  Map<String, dynamic> data, {
  required String fallback,
}) {
  final id = (data['id'] ?? data['sale_id'] ?? data['invoice_id'] ?? '')
      .toString()
      .trim();
  if (id.isNotEmpty) return id;
  return fallback;
}

double _normalizeProfit(Kpis kpis) {
  final sales = kpis.sales;
  final cost = kpis.cost;
  final profit = kpis.profit;
  final scale = (sales.abs() + cost.abs());
  final threshold = scale <= 0 ? 0.0 : scale * 0.001;
  if (profit.abs() <= threshold && (sales != 0 || cost != 0)) {
    return sales - cost;
  }
  return profit;
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
    final snap = await db.collection('archive').get();
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

