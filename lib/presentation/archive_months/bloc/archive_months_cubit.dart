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

  static const _cacheKey = 'archive_months_cache_v4';
  static const _cacheUpdatedKey = 'archive_months_cache_updated_at';
  static const _monthlyCollection = 'archive_months';

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(loading: true, error: null));

    final cached = await _readCache();
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
      unawaited(_fetchRemote(cached: cached, force: force));
      return;
    }

    await _fetchRemote(cached: cached, force: force);
  }

  Future<void> refresh() async {
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
      final query = _db
          .collection(_monthlyCollection)
          .orderBy(FieldPath.documentId, descending: true);

      QuerySnapshot<Map<String, dynamic>> snap = await _getQuerySnapshot(
        query,
        cacheFirst: true,
      );
      if (snap.docs.isEmpty) {
        snap = await _getQuerySnapshot(query, cacheFirst: false);
      }

      final months = snap.docs
          .map((doc) {
            final data = _normalizeMap(doc.data());
            return ArchiveMonth(id: doc.id, data: data);
          })
          .toList();

      if (months.isNotEmpty) {
        final sorted = _sortMonths(months);
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
