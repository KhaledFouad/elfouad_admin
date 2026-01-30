import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elfouad_admin/services/archive/monthly_archive_stats.dart';
import 'package:elfouad_admin/presentation/stats/models/stats_period.dart';
import 'package:elfouad_admin/presentation/stats/utils/stats_data_provider.dart';
import '../models/archive_month.dart';
import 'archive_months_state.dart';

class ArchiveMonthsCubit extends Cubit<ArchiveMonthsState> {
  ArchiveMonthsCubit({FirebaseFirestore? firestore, SharedPreferences? prefs})
    : _db = firestore ?? FirebaseFirestore.instance,
      _prefsFuture = prefs != null
          ? Future<SharedPreferences>.value(prefs)
          : SharedPreferences.getInstance(),
      super(ArchiveMonthsState.initial());

  final FirebaseFirestore _db;
  final Future<SharedPreferences> _prefsFuture;

  static const _cacheKey = 'archive_months_cache_v4';
  static const _cacheUpdatedKey = 'archive_months_cache_updated_at';
  static const _maxYearsBack = 10;
  static const _refreshMonthsBack = 2;
  static const _monthlyCollection = 'archive_months';
  static const List<String> _summaryDocIds = [
    'summary',
    'totals',
    'kpis',
    'stats',
    'month',
  ];

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(loading: true, error: null));

    final cached = await _readCache();
    if (cached.isNotEmpty && !force) {
      final withCurrent = await _addCurrentMonth(cached);
      emit(
        state.copyWith(
          months: withCurrent,
          loading: false,
          fromCache: true,
          error: null,
          lastUpdated: await _readCacheUpdatedAt(),
        ),
      );
      unawaited(_fetchRemote(cached: cached, force: force));
      return;
    }

    await _fetchRemote(cached: cached, force: force);
  }

  Future<void> refresh() async {
    await syncMonthlyArchiveStats(force: true, backfillAllIfNeeded: true);
    await load(force: true);
  }

  Future<DateTime?> _readCacheUpdatedAt() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_cacheUpdatedKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<List<ArchiveMonth>> _readCache() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = decoded
          .whereType<Map>()
          .map((m) => ArchiveMonth.fromCache(m.cast<String, dynamic>()))
          .toList();
      return _sortMonths(list);
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCache(List<ArchiveMonth> months) async {
    final prefs = await _prefsFuture;
    final payload = months.map((m) => m.toCache()).toList();
    await prefs.setString(_cacheKey, jsonEncode(payload));
    await prefs.setString(_cacheUpdatedKey, DateTime.now().toIso8601String());
  }

  Future<void> _fetchRemote({
    required List<ArchiveMonth> cached,
    required bool force,
  }) async {
    try {
      await syncMonthlyArchiveStats(
        force: force,
        backfillAllIfNeeded: true,
      );
      final cachedMap = {for (final m in cached) m.id: m};

      if (force && cachedMap.isNotEmpty) {
        final last = _maxMonthFromCache(cachedMap.values);
        final months = last == null
            ? await _fetchArchiveHierarchy(cached: cachedMap, force: true)
            : await _fetchRecentRange(
                cached: cachedMap,
                start: _rewindMonths(last, _refreshMonthsBack - 1),
              );
        final merged = _mergeMonths(cachedMap, months);
        await _writeCache(_stripCurrentMonth(merged));
        final withCurrent = await _addCurrentMonth(merged);
        emit(
          state.copyWith(
            months: withCurrent,
            loading: false,
            fromCache: false,
            error: null,
            lastUpdated: DateTime.now(),
          ),
        );
        return;
      }

      final monthlySnap = await _getQuerySnapshot(
        _db.collection(_monthlyCollection),
        cacheFirst: false,
      );
      if (monthlySnap.docs.isNotEmpty) {
        final months = monthlySnap.docs
            .map((doc) {
              final data = _normalizeMap(doc.data());
              return ArchiveMonth(id: doc.id, data: data);
            })
            .where((m) => m.data.isNotEmpty && !_isCurrentMonth(m))
            .toList();
        if (months.isNotEmpty) {
          final merged = _mergeMonths(cachedMap, months);
          await _writeCache(_stripCurrentMonth(merged));
          final withCurrent = await _addCurrentMonth(merged);
          emit(
            state.copyWith(
              months: withCurrent,
              loading: false,
              fromCache: false,
              error: null,
              lastUpdated: DateTime.now(),
            ),
          );
          return;
        }
      }

      final months = await _fetchArchiveHierarchy(
        cached: cachedMap,
        force: force,
      );
      final merged = _mergeMonths(cachedMap, months);
      await _writeCache(_stripCurrentMonth(merged));
      final withCurrent = await _addCurrentMonth(merged);
      emit(
        state.copyWith(
          months: withCurrent,
          loading: false,
          fromCache: false,
          error: null,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e));
    }
  }

  List<ArchiveMonth> _mergeMonths(
    Map<String, ArchiveMonth> cached,
    List<ArchiveMonth> fresh,
  ) {
    final merged = Map<String, ArchiveMonth>.from(cached);
    for (final m in fresh) {
      merged[m.id] = m;
    }
    return _sortMonths(merged.values.toList());
  }

  Future<List<ArchiveMonth>> _fetchArchiveHierarchy({
    required Map<String, ArchiveMonth> cached,
    required bool force,
  }) async {
    final now = DateTime.now();
    final cachedMinYear = _minYearFromCache(cached.values);
    final startYear = cachedMinYear ?? (now.year - _maxYearsBack);
    final months = <ArchiveMonth>[];

    for (var year = startYear; year <= now.year; year++) {
      final lastMonth = (year == now.year) ? (now.month - 1) : 12;
      if (lastMonth < 1) continue;
      for (var month = 1; month <= lastMonth; month++) {
        final key = _monthKey(year, month);
        if (!force && cached.containsKey(key)) continue;
        final data = await _readMonthSummary(year, month);
        if (data == null || data.isEmpty) continue;
        data['monthKey'] = key;
        data['year'] = year;
        data['monthNumber'] = month;
        months.add(ArchiveMonth(id: key, data: data));
      }
    }
    return months;
  }

  Future<List<ArchiveMonth>> _fetchRecentRange({
    required Map<String, ArchiveMonth> cached,
    required DateTime start,
  }) async {
    final months = <ArchiveMonth>[];
    final now = DateTime.now();
    final end = DateTime(now.year, now.month - 1, 1);
    var cursor = DateTime(start.year, start.month, 1);

    while (!cursor.isAfter(end)) {
      final key = _monthKey(cursor.year, cursor.month);
      final shouldSkip = cached.containsKey(key) && cursor.isAfter(start);
      if (!shouldSkip) {
        final data = await _readMonthSummary(cursor.year, cursor.month);
        if (data != null && data.isNotEmpty) {
          data['monthKey'] = key;
          data['year'] = cursor.year;
          data['monthNumber'] = cursor.month;
          months.add(ArchiveMonth(id: key, data: data));
        }
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return months;
  }

  int? _minYearFromCache(Iterable<ArchiveMonth> months) {
    int? minYear;
    for (final m in months) {
      final d = m.monthDate;
      if (d == null) continue;
      minYear = minYear == null
          ? d.year
          : (d.year < minYear ? d.year : minYear);
    }
    return minYear;
  }

  DateTime? _maxMonthFromCache(Iterable<ArchiveMonth> months) {
    DateTime? maxMonth;
    for (final m in months) {
      final d = m.monthDate;
      if (d == null) continue;
      final month = DateTime(d.year, d.month, 1);
      if (maxMonth == null || month.isAfter(maxMonth)) {
        maxMonth = month;
      }
    }
    return maxMonth;
  }

  DateTime _rewindMonths(DateTime date, int monthsBack) {
    return DateTime(date.year, date.month - monthsBack, 1);
  }

  String _monthKey(int year, int month) {
    final m = month.toString().padLeft(2, '0');
    return '$year-$m';
  }

  Future<Map<String, dynamic>?> _readMonthSummary(int year, int month) async {
    final monthKey = month.toString().padLeft(2, '0');
    final coll = _db.collection('archive').doc('$year').collection(monthKey);
    final snap = await coll.get();
    if (snap.docs.isEmpty) return null;

    for (final doc in snap.docs) {
      if (!_summaryDocIds.contains(doc.id)) continue;
      final data = doc.data();
      if (data.isNotEmpty) {
        return _normalizeMap(data);
      }
    }

    final raw = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      if (_summaryDocIds.contains(doc.id)) continue;
      raw.add(doc.data());
    }
    if (raw.isEmpty) return null;

    final prepared = prepareStatsData(raw);
    final range = statsComputeRange(
      DateTime(year, month, 1),
      StatsPeriod.fullMonth,
    );
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
    final effectiveProfit = _normalizeProfit(
      sales: kpis.sales,
      cost: kpis.cost,
      profit: kpis.profit,
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
      'year': year,
      'monthNumber': month,
      'monthKey': _monthKey(year, month),
      'rowsCount': raw.length,
      'source': 'archive_sales',
    };
  }

  List<ArchiveMonth> _sortMonths(List<ArchiveMonth> input) {
    final list = List<ArchiveMonth>.from(input);
    list.sort((a, b) {
      final ad = a.monthDate;
      final bd = b.monthDate;
      if (ad == null && bd == null) {
        return b.rawLabel.compareTo(a.rawLabel);
      }
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return list;
  }

  bool _isCurrentMonth(ArchiveMonth month) {
    final now = DateTime.now();
    final d = month.monthDate;
    if (d != null) {
      return d.year == now.year && d.month == now.month;
    }
    return month.id == _monthKey(now.year, now.month);
  }
}

double _normalizeProfit({
  required double sales,
  required double cost,
  required double profit,
}) {
  final scale = (sales.abs() + cost.abs());
  final threshold = scale <= 0 ? 0.0 : scale * 0.001;
  if (profit.abs() <= threshold && (sales != 0 || cost != 0)) {
    return sales - cost;
  }
  return profit;
}

List<ArchiveMonth> _stripCurrentMonth(List<ArchiveMonth> months) {
  final now = DateTime.now();
  return months.where((m) {
    final d = m.monthDate;
    if (d == null) return true;
    return !(d.year == now.year && d.month == now.month);
  }).toList();
}

Future<List<ArchiveMonth>> _addCurrentMonth(List<ArchiveMonth> months) async {
  try {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    final currentKey =
        '${current.year.toString().padLeft(4, '0')}-${current.month.toString().padLeft(2, '0')}';
    final exists =
        months.any((m) => m.id == currentKey || m.monthDate == current);
    if (exists) return months;

    final raw = prepareStatsData(
      await fetchSalesRawForMonth(current, cacheFirst: true),
    );
    final range = statsComputeRange(current, StatsPeriod.fullMonth);
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
    final filtered = filterStatsSales(
      raw,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    );
    final kpis = buildKpis(
      filtered,
      expenses,
      startUtc: range.startUtc,
      endUtc: range.endUtc,
    );
    final effectiveProfit = _normalizeProfit(
      sales: kpis.sales,
      cost: kpis.cost,
      profit: kpis.profit,
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

    final data = {
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
      'year': current.year,
      'monthNumber': current.month,
      'monthKey': currentKey,
      'source': 'live_stats',
      'rowsCount': filtered.length,
    };

    final withCurrent = List<ArchiveMonth>.from(months)
      ..add(ArchiveMonth(id: currentKey, data: data));
    return _sortMonthsExternal(withCurrent);
  } catch (_) {
    return months;
  }
}

List<ArchiveMonth> _sortMonthsExternal(List<ArchiveMonth> input) {
  final list = List<ArchiveMonth>.from(input);
  list.sort((a, b) {
    final ad = a.monthDate;
    final bd = b.monthDate;
    if (ad == null && bd == null) {
      return b.rawLabel.compareTo(a.rawLabel);
    }
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });
  return list;
}

Map<String, dynamic> _normalizeMap(Map<String, dynamic> map) {
  final out = <String, dynamic>{};
  map.forEach((key, value) {
    out[key] = _normalizeValue(value);
  });
  return out;
}

dynamic _normalizeValue(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is DocumentReference) {
    return value.path;
  }
  if (value is Map) {
    return _normalizeMap(value.cast<String, dynamic>());
  }
  if (value is List) {
    return value.map(_normalizeValue).toList();
  }
  if (value is num || value is String || value is bool) return value;
  return value.toString();
}

Future<QuerySnapshot<Map<String, dynamic>>> _getQuerySnapshot(
  Query<Map<String, dynamic>> query, {
  bool cacheFirst = false,
}) async {
  if (!cacheFirst) return query.get();
  try {
    final cached = await query.get(const GetOptions(source: Source.cache));
    if (cached.docs.isNotEmpty) return cached;
  } catch (_) {}
  return query.get();
}
