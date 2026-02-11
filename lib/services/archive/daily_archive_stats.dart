import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elfouad_admin/presentation/stats/models/stats_models.dart'
    show GroupRow, Kpis;
import 'package:elfouad_admin/presentation/stats/models/stats_period.dart';
import 'package:elfouad_admin/presentation/stats/utils/op_day.dart';
import 'package:elfouad_admin/presentation/stats/utils/stats_data_provider.dart';

const String _dailyArchivePrefKey = 'archive_daily_last_sync';
const List<String> _salesCollections = ['sales', 'deferred_sales'];
const List<String> _summaryDocIds = [
  'summary',
  'totals',
  'kpis',
  'stats',
  'month',
];

Future<void> syncDailyArchiveStats({
  FirebaseFirestore? firestore,
  SharedPreferences? prefs,
  int defaultBackfillDays = 3,
  int maxBackfillDays = 31,
  bool allowExtendedBackfill = false,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final localPrefs = prefs ?? await SharedPreferences.getInstance();

  final now = DateTime.now();
  final todayStartLocal = opStartLocal(now);
  final todayKey = opDayKeyFromLocal(now);

  final lastKey = localPrefs.getString(_dailyArchivePrefKey);
  final lastDay = _parseDayKey(lastKey);

  final safeDefault = defaultBackfillDays < 1 ? 1 : defaultBackfillDays;
  final safeMax = maxBackfillDays < safeDefault ? safeDefault : maxBackfillDays;

  DateTime startLocal;
  if (lastDay == null) {
    startLocal = _windowStartLocal(
      todayStartLocal,
      allowExtendedBackfill ? safeMax : safeDefault,
    );
  } else {
    final lastStart = DateTime(lastDay.year, lastDay.month, lastDay.day, 12);
    startLocal = opStartLocal(lastStart).add(const Duration(days: 1));
  }

  final defaultStart = _windowStartLocal(todayStartLocal, safeDefault);
  if (startLocal.isBefore(defaultStart)) {
    if (allowExtendedBackfill) {
      final maxStart = _windowStartLocal(todayStartLocal, safeMax);
      if (startLocal.isBefore(maxStart)) {
        startLocal = maxStart;
      }
    } else {
      startLocal = defaultStart;
    }
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

Future<void> syncDailyArchiveForDay({
  FirebaseFirestore? firestore,
  required DateTime dayLocal,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  await _syncOneDay(db, opStartLocal(dayLocal));
}

Future<void> backfillDailyArchiveForMonth({
  FirebaseFirestore? firestore,
  required DateTime month,
  bool includeLiveSales = true,
  bool refreshExisting = false,
  bool writeEmptyDays = false,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final year = month.year;
  final monthKey = month.month.toString().padLeft(2, '0');
  final daysInMonth = DateUtils.getDaysInMonth(year, month.month);

  final dailyRef = db
      .collection('archive_daily')
      .doc('$year')
      .collection(monthKey);

  QuerySnapshot<Map<String, dynamic>> dailySnap;
  try {
    dailySnap = await dailyRef.get();
  } catch (_) {
    return;
  }

  final existing = dailySnap.docs.map((d) => d.id).toSet();
  if (!refreshExisting && existing.length >= daysInMonth) return;

  final rawById = await _fetchArchiveSalesForMonth(
    db,
    month,
    includeLiveSales: includeLiveSales,
  );
  if (rawById.isEmpty) return;

  final rawList = rawById.values.toList();
  final prepared = prepareStatsData(rawList);

  final range = statsComputeRange(month, StatsPeriod.fullMonth);
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

  WriteBatch batch = db.batch();
  int ops = 0;

  for (var day = 1; day <= daysInMonth; day++) {
    final dayStartLocal = DateTime(year, month.month, day, kOpShiftHours);
    final dayKey = opDayKeyFromLocal(dayStartLocal);
    if (!refreshExisting && existing.contains(dayKey)) continue;

    final startUtc = dayStartLocal.toUtc();
    final endUtc = dayStartLocal.add(const Duration(days: 1)).toUtc();

    final filteredSales = filterStatsSales(
      prepared,
      startUtc: startUtc,
      endUtc: endUtc,
    );
    final filteredExpenses = filterStatsExpenses(
      expenses,
      startUtc: startUtc,
      endUtc: endUtc,
    );
    final kpis = buildKpis(
      filteredSales,
      filteredExpenses,
      startUtc: startUtc,
      endUtc: endUtc,
    );

    final highlights = buildHighlights(
      filteredSales,
      startUtc: startUtc,
      endUtc: endUtc,
    );
    final drinksRows = buildDrinksRows(
      filteredSales,
      startUtc: startUtc,
      endUtc: endUtc,
    );
    final beansRows = buildBeansRows(
      filteredSales,
      startUtc: startUtc,
      endUtc: endUtc,
    );
    final turkishRows = buildTurkishRows(
      filteredSales,
      startUtc: startUtc,
      endUtc: endUtc,
    );
    final extrasRows = buildExtrasRows(
      filteredSales,
      startUtc: startUtc,
      endUtc: endUtc,
    );

    final hasAny = _hasAnyDailyData(
      kpis: kpis,
      orders: highlights.totalOrders,
      drinksRows: drinksRows,
      beansRows: beansRows,
      turkishRows: turkishRows,
      extrasRows: extrasRows,
    );

    if (!hasAny && !writeEmptyDays) continue;

    final ref = dailyRef.doc(dayKey);
    batch.set(
      ref,
      _buildDailyPayload(
        dayStartLocal: dayStartLocal,
        startUtc: startUtc,
        endUtc: endUtc,
        kpis: kpis,
        orders: highlights.totalOrders,
        drinksRows: drinksRows,
        beansRows: beansRows,
        turkishRows: turkishRows,
        extrasRows: extrasRows,
      ),
      SetOptions(merge: true),
    );
    ops += 1;

    if (ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) {
    await batch.commit();
  }
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

  final highlights = buildHighlights(
    filtered,
    startUtc: startUtc,
    endUtc: endUtc,
  );
  final drinksRows = buildDrinksRows(
    filtered,
    startUtc: startUtc,
    endUtc: endUtc,
  );
  final beansRows = buildBeansRows(
    filtered,
    startUtc: startUtc,
    endUtc: endUtc,
  );
  final turkishRows = buildTurkishRows(
    filtered,
    startUtc: startUtc,
    endUtc: endUtc,
  );
  final extrasRows = buildExtrasRows(
    filtered,
    startUtc: startUtc,
    endUtc: endUtc,
  );

  final hasAny = _hasAnyDailyData(
    kpis: kpis,
    orders: highlights.totalOrders,
    drinksRows: drinksRows,
    beansRows: beansRows,
    turkishRows: turkishRows,
    extrasRows: extrasRows,
  );

  if (!hasAny) return;

  final dayKey = opDayKeyFromLocal(dayStartLocal);
  final year = dayStartLocal.year;
  final monthKey = dayStartLocal.month.toString().padLeft(2, '0');

  final ref = db
      .collection('archive_daily')
      .doc('$year')
      .collection(monthKey)
      .doc(dayKey);

  await ref.set(
    _buildDailyPayload(
      dayStartLocal: dayStartLocal,
      startUtc: startUtc,
      endUtc: endUtc,
      kpis: kpis,
      orders: highlights.totalOrders,
      drinksRows: drinksRows,
      beansRows: beansRows,
      turkishRows: turkishRows,
      extrasRows: extrasRows,
    ),
    SetOptions(merge: true),
  );
}

Future<Map<String, Map<String, dynamic>>> _fetchArchiveSalesForMonth(
  FirebaseFirestore db,
  DateTime month, {
  required bool includeLiveSales,
}) async {
  final year = month.year;
  final monthKey = month.month.toString().padLeft(2, '0');
  final out = <String, Map<String, dynamic>>{};

  try {
    final snap = await db
        .collection('archive')
        .doc('$year')
        .collection(monthKey)
        .get();
    for (final doc in snap.docs) {
      if (_summaryDocIds.contains(doc.id)) continue;
      final data = doc.data();
      final id = _pickSaleId(data, fallback: doc.id);
      if (id.isEmpty) continue;
      out[id] = data;
    }
  } catch (_) {}

  final fromBin = await _fetchArchiveBinForMonth(db, month);
  for (final entry in fromBin) {
    final id = _pickSaleId(entry, fallback: '');
    if (id.isEmpty) continue;
    out.putIfAbsent(id, () => entry);
  }

  if (includeLiveSales) {
    final liveRaw = await fetchSalesRawForMonth(month, cacheFirst: true);
    for (final sale in liveRaw) {
      final id = _pickSaleId(sale, fallback: (sale['id'] ?? '').toString());
      if (id.isEmpty) continue;
      out.putIfAbsent(id, () => sale);
    }
  }

  return out;
}

Future<List<Map<String, dynamic>>> _fetchArchiveBinForMonth(
  FirebaseFirestore db,
  DateTime month,
) async {
  final range = statsComputeRange(month, StatsPeriod.fullMonth);
  final startUtc = range.startUtc;
  final endUtc = range.endUtc;
  final targetMonthKey =
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

  final out = <Map<String, dynamic>>[];
  DocumentSnapshot<Map<String, dynamic>>? last;

  while (true) {
    // Keep this query index-light to avoid requiring composite indexes on
    // background maintenance. We filter by kind/time in memory.
    Query<Map<String, dynamic>> q = db
        .collection('archive_bin')
        .where('month_key', isEqualTo: targetMonthKey)
        .limit(400);
    if (last != null) q = q.startAfterDocument(last);

    final snap = await q.get();
    if (snap.docs.isEmpty) break;

    for (final doc in snap.docs) {
      final entry = doc.data();
      if ((entry['kind'] ?? '').toString() != 'sale') continue;
      final dataRaw = entry['data'];
      if (dataRaw is! Map) continue;
      final data = dataRaw.cast<String, dynamic>();
      if (!data.containsKey('created_at') &&
          entry.containsKey('created_at_original')) {
        data['created_at'] = entry['created_at_original'];
      }
      if (!_saleInRange(data, startUtc: startUtc, endUtc: endUtc)) continue;
      out.add(data);
    }

    last = snap.docs.last;
  }

  return out;
}

String _pickSaleId(Map<String, dynamic> data, {required String fallback}) {
  final id = (data['id'] ?? data['sale_id'] ?? data['invoice_id'] ?? '')
      .toString()
      .trim();
  if (id.isNotEmpty) return id;
  return fallback;
}

DateTime _asUtc(dynamic v) {
  if (v is DateTime) return v.toUtc();
  try {
    // Firestore Timestamp (dynamic)
    // ignore: avoid_dynamic_calls
    if (v != null && v.toDate != null) {
      // ignore: avoid_dynamic_calls
      final dt = v.toDate();
      if (dt is DateTime) return dt.toUtc();
    }
  } catch (_) {}
  if (v is num) {
    final raw = v.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  if (v is String) {
    return DateTime.tryParse(v)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime _productionUtc(Map<String, dynamic> m) {
  final orig = m['original_created_at'];
  final origUtc = orig == null ? null : _asUtc(orig);
  if (origUtc != null && origUtc.millisecondsSinceEpoch > 0) return origUtc;
  return _asUtc(m['created_at']);
}

DateTime _financialUtc(Map<String, dynamic> m) {
  final created = _asUtc(m['created_at']);
  final settledRaw = m['settled_at'];
  final settled = settledRaw == null ? null : _asUtc(settledRaw);
  final updatedRaw = m['updated_at'];
  final updated = updatedRaw == null ? null : _asUtc(updatedRaw);

  final isDeferred = (m['is_deferred'] ?? false) == true;
  final paid = (m['paid'] ?? (!isDeferred)) == true;

  if (paid) {
    if (settled != null && settled.millisecondsSinceEpoch > 0) {
      return settled;
    }
    if (updated != null && updated.millisecondsSinceEpoch > 0) {
      return updated;
    }
  }
  return created;
}

bool _inRangeUtc(DateTime ts, DateTime start, DateTime end) {
  final afterOrEqual = ts.isAtSameMomentAs(start) || ts.isAfter(start);
  final before = ts.isBefore(end);
  return afterOrEqual && before;
}

bool _saleInRange(
  Map<String, dynamic> m, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final inProd = _inRangeUtc(_productionUtc(m), startUtc, endUtc);
  final inFin = _inRangeUtc(_financialUtc(m), startUtc, endUtc);
  final isDeferred = (m['is_deferred'] ?? false) == true;
  final paid = (m['paid'] ?? (!isDeferred)) == true;
  if (isDeferred && !paid) return inProd;
  return inProd || inFin;
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

  void mergeDocs(QuerySnapshot<Map<String, dynamic>> snap, String collection) {
    for (final d in snap.docs) {
      final m = d.data();
      if (collection == 'deferred_sales' &&
          (m['is_deferred'] ?? false) != true) {
        m['is_deferred'] = true;
      }
      m['id'] = d.id;
      combined[d.id] = m;
    }
  }

  Future<void> mergeRange(
    String collection,
    String field, {
    required dynamic start,
    required dynamic end,
  }) async {
    try {
      final snap = await _getQuerySnapshot(
        db
            .collection(collection)
            .where(field, isGreaterThanOrEqualTo: start)
            .where(field, isLessThan: end)
            .orderBy(field, descending: false),
      );
      mergeDocs(snap, collection);
    } catch (_) {}
  }

  Future<void> mergeStage({
    required dynamic start,
    required dynamic end,
  }) async {
    for (final collection in _salesCollections) {
      await mergeRange(collection, 'created_at', start: start, end: end);
      await mergeRange(
        collection,
        'original_created_at',
        start: start,
        end: end,
      );
      if (collection == 'deferred_sales') {
        await mergeRange(collection, 'settled_at', start: start, end: end);
        await mergeRange(collection, 'updated_at', start: start, end: end);
        await mergeRange(collection, 'last_payment_at', start: start, end: end);
      }
    }
  }

  await mergeStage(start: startUtc, end: endUtc);
  if (combined.isNotEmpty) return combined.values.toList();

  await mergeStage(start: startIso, end: endIso);
  if (combined.isNotEmpty) return combined.values.toList();

  await mergeStage(start: startMs, end: endMs);

  return combined.values.toList();
}

DateTime _windowStartLocal(DateTime todayStartLocal, int daysInclusive) {
  final safeDays = daysInclusive < 1 ? 1 : daysInclusive;
  return todayStartLocal.subtract(Duration(days: safeDays - 1));
}

bool _hasAnyDailyData({
  required Kpis kpis,
  required int orders,
  required List<GroupRow> drinksRows,
  required List<GroupRow> beansRows,
  required List<GroupRow> turkishRows,
  required List<GroupRow> extrasRows,
}) {
  return kpis.sales != 0 ||
      kpis.cost != 0 ||
      kpis.profit != 0 ||
      kpis.cups != 0 ||
      kpis.grams != 0 ||
      kpis.units != 0 ||
      kpis.expenses != 0 ||
      orders != 0 ||
      drinksRows.isNotEmpty ||
      beansRows.isNotEmpty ||
      turkishRows.isNotEmpty ||
      extrasRows.isNotEmpty;
}

Map<String, dynamic> _buildDailyPayload({
  required DateTime dayStartLocal,
  required DateTime startUtc,
  required DateTime endUtc,
  required Kpis kpis,
  required int orders,
  required List<GroupRow> drinksRows,
  required List<GroupRow> beansRows,
  required List<GroupRow> turkishRows,
  required List<GroupRow> extrasRows,
}) {
  final dayKey = opDayKeyFromLocal(dayStartLocal);
  final drinksSummary = _rowsSummary(drinksRows);
  final extrasSummary = _rowsSummary(extrasRows);
  return {
    'dayKey': dayKey,
    'year': dayStartLocal.year,
    'monthNumber': dayStartLocal.month,
    'dayNumber': dayStartLocal.day,
    'startUtc': startUtc.toIso8601String(),
    'endUtc': endUtc.toIso8601String(),
    'sales': kpis.sales,
    'cost': kpis.cost,
    'profit': kpis.profit,
    'grams': kpis.grams,
    'cups': kpis.cups,
    'units': kpis.units,
    // Backward compatibility with older readers.
    'drinks': kpis.cups,
    'snacks': kpis.units,
    'expenses': kpis.expenses,
    'orders': orders,
    'drinks_rows': _encodeRows(drinksRows),
    // Keep an explicit alias for UI details to avoid schema mismatch.
    'drinks_details_rows': _encodeRows(drinksRows),
    'beans_rows': _encodeRows(beansRows),
    'turkish_rows': _encodeRows(turkishRows, turkish: true),
    'extras_rows': _encodeRows(extrasRows),
    'extras_details_rows': _encodeRows(extrasRows),
    // Explicit numeric totals for drinks/snacks details.
    'drinks_sales': drinksSummary.sales,
    'drinks_cost': drinksSummary.cost,
    'drinks_profit': drinksSummary.profit,
    'drinks_count': drinksSummary.count,
    'extras_sales': extrasSummary.sales,
    'extras_cost': extrasSummary.cost,
    'extras_profit': extrasSummary.profit,
    'extras_count': extrasSummary.count,
    'updated_at': FieldValue.serverTimestamp(),
  };
}

List<Map<String, dynamic>> _encodeRows(
  List<GroupRow> rows, {
  bool turkish = false,
}) {
  return rows
      .map(
        (row) => {
          'key': row.key,
          'name': row.key,
          'sales': row.sales,
          'cost': row.cost,
          'profit': row.profit,
          'grams': row.grams,
          'plainGrams': row.plainGrams,
          'spicedGrams': row.spicedGrams,
          'cups': row.cups,
          if (turkish) 'plainCups': row.plainGrams.round(),
          if (turkish) 'spicedCups': row.spicedGrams.round(),
        },
      )
      .toList();
}

({double sales, double cost, double profit, int count}) _rowsSummary(
  List<GroupRow> rows,
) {
  double sales = 0;
  double cost = 0;
  double profit = 0;
  int count = 0;
  for (final row in rows) {
    sales += row.sales;
    cost += row.cost;
    profit += row.profit;
    count += row.cups;
  }
  return (sales: sales, cost: cost, profit: profit, count: count);
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
