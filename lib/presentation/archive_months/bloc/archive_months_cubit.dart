import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const _cacheKey = 'archive_months_cache_v5';
  static const _cacheUpdatedKey = 'archive_months_cache_updated_at';
  static const _dailyCollection = 'archive_daily';
  static const _legacyMonthlyCollection = 'archive_months';
  static const _refreshRecentClosedMonthsCount = 2;
  static const _backgroundRefreshInterval = Duration(hours: 8);

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final cached = _filterClosedMonths(await _readCache());
      final lastUpdated = await _readCacheUpdatedAt();
      if (cached.isNotEmpty && !force) {
        emit(
          state.copyWith(
            months: cached,
            loading: false,
            fromCache: true,
            error: null,
            lastUpdated: lastUpdated,
          ),
        );
        unawaited(
          _refreshRemoteIfNeeded(cached: cached, lastUpdated: lastUpdated),
        );
        return;
      }

      await _fetchRemote(cached: cached, force: force);
    } catch (e) {
      emit(state.copyWith(loading: false, error: e));
    }
  }

  Future<void> refresh() async {
    await load(force: true);
  }

  Future<void> _refreshRemoteIfNeeded({
    required List<ArchiveMonth> cached,
    required DateTime? lastUpdated,
  }) async {
    final staleOrMissingLatest = _shouldRefreshRemote(
      cached: cached,
      lastUpdated: lastUpdated,
    );
    final hasGaps = await _hasKnownClosedMonthGaps(cached, cacheFirst: true);
    if (!staleOrMissingLatest && !hasGaps) return;
    await _fetchRemote(cached: cached, force: false);
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
      List<ArchiveMonth> months;
      if (!force && cached.isNotEmpty) {
        final latestClosed = _latestClosedMonthStart();
        final latestClosedKey = latestClosed == null
            ? null
            : _monthKey(latestClosed);
        final cacheHasLatestClosed =
            latestClosedKey != null &&
            cached.any(
              (month) => _monthKeyForArchiveMonth(month) == latestClosedKey,
            );
        final hasGaps = await _hasKnownClosedMonthGaps(
          cached,
          cacheFirst: true,
        );

        if (!cacheHasLatestClosed || hasGaps) {
          months = await _fetchAllClosedMonthsFromDaily(cacheFirst: true);
        } else {
          months = await _refreshRecentClosedMonths(cached, cacheFirst: true);
        }
      } else {
        months = await _fetchAllClosedMonthsFromDaily(cacheFirst: !force);
      }

      if (months.isNotEmpty) {
        final sorted = _filterClosedMonths(_sortMonths(months));
        await _writeCache(sorted);
        emit(
          state.copyWith(
            months: sorted,
            loading: false,
            fromCache: false,
            error: null,
            lastUpdated: DateTime.now(),
          ),
        );
        return;
      }

      if (cached.isNotEmpty && !force) {
        emit(
          state.copyWith(
            months: cached,
            loading: false,
            fromCache: true,
            error: null,
            lastUpdated: await _readCacheUpdatedAt(),
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          months: const [],
          loading: false,
          fromCache: false,
          error: null,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      if (cached.isNotEmpty && !force) {
        emit(
          state.copyWith(
            months: cached,
            loading: false,
            fromCache: true,
            error: e,
            lastUpdated: await _readCacheUpdatedAt(),
          ),
        );
        return;
      }
      emit(state.copyWith(loading: false, error: e));
    }
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

  List<ArchiveMonth> _filterClosedMonths(List<ArchiveMonth> months) {
    final currentMonthStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );
    return months
        .where((m) => _isClosedMonth(m, currentMonthStart: currentMonthStart))
        .toList();
  }

  bool _isClosedMonth(
    ArchiveMonth month, {
    required DateTime currentMonthStart,
  }) {
    final monthDate = month.monthDate;
    if (monthDate == null) return true;
    return monthDate.isBefore(currentMonthStart);
  }

  bool _shouldRefreshRemote({
    required List<ArchiveMonth> cached,
    required DateTime? lastUpdated,
  }) {
    if (cached.isEmpty) return true;

    final latestClosed = _latestClosedMonthStart();
    if (latestClosed != null) {
      final latestClosedKey = _monthKey(latestClosed);
      final cacheHasLatestClosed = cached.any(
        (month) => _monthKeyForArchiveMonth(month) == latestClosedKey,
      );
      if (!cacheHasLatestClosed) return true;
    }

    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated) >= _backgroundRefreshInterval;
  }

  DateTime? _latestClosedMonthStart() {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final latestClosed = DateTime(
      currentMonthStart.year,
      currentMonthStart.month - 1,
      1,
    );
    return latestClosed;
  }

  Future<bool> _hasKnownClosedMonthGaps(
    List<ArchiveMonth> cached, {
    required bool cacheFirst,
  }) async {
    if (cached.isEmpty) return true;

    final knownKeys = await _discoverKnownClosedMonthKeys(
      cacheFirst: cacheFirst,
    );
    if (knownKeys.isEmpty) return false;

    final cachedKeys = cached
        .map(_monthKeyForArchiveMonth)
        .where((key) => key.isNotEmpty)
        .toSet();

    for (final key in knownKeys) {
      if (!cachedKeys.contains(key)) return true;
    }
    return false;
  }

  Future<Set<String>> _discoverKnownClosedMonthKeys({
    required bool cacheFirst,
  }) async {
    final keys = <String>{};
    final years = await _discoverDailyYears(cacheFirst: cacheFirst);

    if (years.isNotEmpty) {
      final now = DateTime.now();
      for (final year in years) {
        final maxMonth = year < now.year
            ? 12
            : (year == now.year ? now.month - 1 : 0);
        if (maxMonth < 1) continue;
        for (var month = 1; month <= maxMonth; month++) {
          keys.add(_monthKey(DateTime(year, month, 1)));
        }
      }
      return keys;
    }

    keys.addAll(await _discoverLegacyMonthKeys(cacheFirst: cacheFirst));
    return keys;
  }

  String _monthKeyForArchiveMonth(ArchiveMonth month) {
    final parsed = month.monthDate ?? _parseMonthKey(month.id);
    if (parsed == null) return month.id.trim();
    return _monthKey(parsed);
  }

  Future<List<ArchiveMonth>> _fetchAllClosedMonthsFromDaily({
    required bool cacheFirst,
  }) async {
    final candidates = await _discoverCandidateMonthKeys(
      cacheFirst: cacheFirst,
    );
    if (candidates.isEmpty) return const [];

    final out = <ArchiveMonth>[];
    final currentMonthStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );

    for (final monthKey in candidates) {
      final monthDate = _parseMonthKey(monthKey);
      if (monthDate == null) continue;
      if (!monthDate.isBefore(currentMonthStart)) continue;

      final month = await _buildMonthFromDaily(
        monthDate,
        cacheFirst: cacheFirst,
      );
      if (month != null) out.add(month);
    }

    return _sortMonths(out);
  }

  Future<List<ArchiveMonth>> _refreshRecentClosedMonths(
    List<ArchiveMonth> cached, {
    required bool cacheFirst,
  }) async {
    final merged = <String, ArchiveMonth>{};
    for (final month in cached) {
      final key = _monthKeyForArchiveMonth(month);
      if (key.isEmpty) continue;
      merged[key] = month;
    }

    final targets = _recentClosedMonths(_refreshRecentClosedMonthsCount);
    for (final monthDate in targets) {
      final rebuilt = await _buildMonthFromDaily(
        monthDate,
        cacheFirst: cacheFirst,
      );
      if (rebuilt == null) continue;
      merged[_monthKey(monthDate)] = rebuilt;
    }

    return _sortMonths(merged.values.toList());
  }

  List<DateTime> _recentClosedMonths(int count) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final out = <DateTime>[];
    for (var i = 1; i <= count; i++) {
      out.add(DateTime(currentMonthStart.year, currentMonthStart.month - i, 1));
    }
    return out;
  }

  Future<List<String>> _discoverCandidateMonthKeys({
    required bool cacheFirst,
  }) async {
    final keys = <String>{};

    final years = await _discoverDailyYears(cacheFirst: cacheFirst);
    if (years.isNotEmpty) {
      final now = DateTime.now();
      for (final year in years) {
        final maxMonth = year < now.year
            ? 12
            : (year == now.year ? now.month - 1 : 0);
        if (maxMonth < 1) continue;
        for (var month = 1; month <= maxMonth; month++) {
          keys.add(_monthKey(DateTime(year, month, 1)));
        }
      }
    }

    if (keys.isEmpty) {
      keys.addAll(await _discoverLegacyMonthKeys(cacheFirst: cacheFirst));
    }

    if (keys.isEmpty) {
      keys.addAll(_fallbackRecentClosedMonthKeys(monthsBack: 18));
    }

    final list = keys.toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  }

  Future<List<int>> _discoverDailyYears({required bool cacheFirst}) async {
    try {
      final snap = await _getQuerySnapshot(
        _db.collection(_dailyCollection),
        cacheFirst: cacheFirst,
      );
      final years = <int>[];
      for (final doc in snap.docs) {
        final y = int.tryParse(doc.id.trim());
        if (y == null) continue;
        years.add(y);
      }
      years.sort((a, b) => a.compareTo(b));
      return years;
    } catch (_) {
      return const [];
    }
  }

  Future<Set<String>> _discoverLegacyMonthKeys({
    required bool cacheFirst,
  }) async {
    try {
      final snap = await _getQuerySnapshot(
        _db.collection(_legacyMonthlyCollection),
        cacheFirst: cacheFirst,
      );
      final out = <String>{};
      final currentMonthStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );
      for (final doc in snap.docs) {
        final month = _parseMonthKey(doc.id);
        if (month == null) continue;
        if (!month.isBefore(currentMonthStart)) continue;
        out.add(_monthKey(month));
      }
      return out;
    } catch (_) {
      return <String>{};
    }
  }

  Set<String> _fallbackRecentClosedMonthKeys({required int monthsBack}) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final out = <String>{};
    for (var i = 1; i <= monthsBack; i++) {
      out.add(
        _monthKey(
          DateTime(currentMonthStart.year, currentMonthStart.month - i, 1),
        ),
      );
    }
    return out;
  }

  Future<ArchiveMonth?> _buildMonthFromDaily(
    DateTime month, {
    required bool cacheFirst,
  }) async {
    final year = month.year.toString();
    final monthKey = month.month.toString().padLeft(2, '0');
    final query = _db
        .collection(_dailyCollection)
        .doc(year)
        .collection(monthKey);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _getQuerySnapshot(query, cacheFirst: cacheFirst);
    } catch (_) {
      return null;
    }
    if (snap.docs.isEmpty) return null;

    final rollup = _MonthlyRollup(month);
    for (final doc in snap.docs) {
      rollup.addDay(doc.data());
    }
    return rollup.toArchiveMonth();
  }
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

class _MonthlyRollup {
  _MonthlyRollup(this.monthStart);

  final DateTime monthStart;
  double sales = 0;
  double cost = 0;
  double profit = 0;
  double grams = 0;
  double expenses = 0;
  int cups = 0;
  int units = 0;
  int orders = 0;
  int daysCount = 0;
  final Map<String, _RollupRow> beansRows = <String, _RollupRow>{};
  final Map<String, _RollupRow> turkishRows = <String, _RollupRow>{};

  void addDay(Map<String, dynamic> day) {
    daysCount += 1;
    sales += _toDouble(day['sales']);
    cost += _toDouble(day['cost']);
    profit += _toDouble(day['profit']);
    grams += _toDouble(day['grams']);
    expenses += _toDouble(day['expenses']);
    cups += _toInt(day['cups'] ?? day['drinks']);
    units += _toInt(day['units'] ?? day['snacks']);
    orders += _toInt(day['orders']);

    _accumulateRows(day['beans_rows'], beansRows, turkish: false);
    _accumulateRows(day['turkish_rows'], turkishRows, turkish: true);
  }

  ArchiveMonth toArchiveMonth() {
    final monthKey = _monthKey(monthStart);
    return ArchiveMonth(
      id: monthKey,
      data: {
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
        'beans_rows': _encodeRows(beansRows.values, sortByCups: false),
        'turkish_rows': _encodeRows(turkishRows.values, sortByCups: true),
        'daysCount': daysCount,
        'monthKey': monthKey,
        'year': monthStart.year,
        'monthNumber': monthStart.month,
        'source': 'archive_daily_rollup',
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  void _accumulateRows(
    dynamic rawRows,
    Map<String, _RollupRow> target, {
    required bool turkish,
  }) {
    if (rawRows is! List) return;
    for (final entry in rawRows) {
      final map = _asStringMap(entry);
      if (map.isEmpty) continue;

      final key = _rowKey(map);
      if (key.isEmpty) continue;
      final name = _rowName(map, fallback: key);

      final row = target.putIfAbsent(
        key,
        () => _RollupRow(key: key, name: name),
      );
      if (row.name == row.key && name.isNotEmpty) {
        row.name = name;
      }

      row.sales += _toDouble(map['sales']);
      row.cost += _toDouble(map['cost']);
      row.profit += _toDouble(map['profit']);
      row.grams += _toDouble(map['grams']);

      final plainGrams = _toDouble(map['plainGrams'] ?? map['plain_grams']);
      final spicedGrams = _toDouble(map['spicedGrams'] ?? map['spiced_grams']);
      row.plainGrams += plainGrams;
      row.spicedGrams += spicedGrams;

      if (turkish) {
        final plainCups = _toInt(
          map['plainCups'] ?? map['plain_cups'] ?? map['plainGrams'],
        );
        final spicedCups = _toInt(
          map['spicedCups'] ?? map['spiced_cups'] ?? map['spicedGrams'],
        );
        row.plainCups += plainCups;
        row.spicedCups += spicedCups;
      }

      var cupsVal = _toInt(map['cups']);
      if (turkish && cupsVal == 0) {
        cupsVal =
            _toInt((map['plainCups'] ?? map['plain_cups'] ?? 0)) +
            _toInt((map['spicedCups'] ?? map['spiced_cups'] ?? 0));
        if (cupsVal == 0) {
          cupsVal =
              _toInt((map['plainGrams'] ?? map['plain_grams'] ?? 0)) +
              _toInt((map['spicedGrams'] ?? map['spiced_grams'] ?? 0));
        }
      }
      row.cups += cupsVal;
    }
  }

  List<Map<String, dynamic>> _encodeRows(
    Iterable<_RollupRow> rows, {
    required bool sortByCups,
  }) {
    final list = rows.toList();
    list.sort((a, b) {
      final byPrimary = sortByCups
          ? b.cups.compareTo(a.cups)
          : b.sales.compareTo(a.sales);
      if (byPrimary != 0) return byPrimary;
      final bySales = b.sales.compareTo(a.sales);
      if (bySales != 0) return bySales;
      return a.name.compareTo(b.name);
    });

    return list
        .map(
          (row) => {
            'key': row.key,
            'name': row.name,
            'sales': row.sales,
            'cost': row.cost,
            'profit': row.profit,
            'grams': row.grams,
            'plainGrams': row.plainGrams,
            'spicedGrams': row.spicedGrams,
            'cups': row.cups,
            'plainCups': row.plainCups,
            'spicedCups': row.spicedCups,
          },
        )
        .toList();
  }
}

class _RollupRow {
  _RollupRow({required this.key, required this.name});

  final String key;
  String name;
  double sales = 0;
  double cost = 0;
  double profit = 0;
  double grams = 0;
  double plainGrams = 0;
  double spicedGrams = 0;
  int cups = 0;
  int plainCups = 0;
  int spicedCups = 0;
}

Map<String, dynamic> _asStringMap(dynamic entry) {
  if (entry is Map<String, dynamic>) return entry;
  if (entry is Map) {
    return entry.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

String _rowKey(Map<String, dynamic> map) {
  final key = (map['key'] ?? map['name'] ?? '').toString().trim();
  return key;
}

String _rowName(Map<String, dynamic> map, {required String fallback}) {
  final name = (map['name'] ?? map['key'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  return fallback;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }
  return 0.0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _monthKey(DateTime month) {
  final m = month.month.toString().padLeft(2, '0');
  return '${month.year}-$m';
}

DateTime? _parseMonthKey(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(trimmed);
  if (match == null) return null;
  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  if (year == null || month == null) return null;
  return DateTime(year, month, 1);
}
