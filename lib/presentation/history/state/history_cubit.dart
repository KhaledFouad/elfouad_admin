import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const int kHistoryPageSize = 120;

DateTime _createdAtOf(Map<String, dynamic> m) {
  final v = m['created_at'];
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is num) {
    final raw = v.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return DateTime.tryParse('$v') ?? DateTime.fromMillisecondsSinceEpoch(0);
}

Query<Map<String, dynamic>> _salesQuery(
  FirebaseFirestore firestore,
  DateTimeRange r, {
  required bool stringRange,
  required int limit,
  QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
}) {
  final end = stringRange ? r.end.toUtc().toIso8601String() : r.end.toUtc();
  var q = firestore
      .collection('sales')
      .where('created_at', isLessThan: end)
      .orderBy('created_at', descending: true)
      .limit(limit);
  if (startAfter != null) {
    q = q.startAfterDocument(startAfter);
  }
  return q;
}

Query<Map<String, dynamic>> _salesQueryNum(
  FirebaseFirestore firestore,
  DateTimeRange r, {
  required int limit,
  QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
}) {
  final endMs = r.end.toUtc().millisecondsSinceEpoch;
  var q = firestore
      .collection('sales')
      .where('created_at', isLessThan: endMs)
      .orderBy('created_at', descending: true)
      .limit(limit);
  if (startAfter != null) {
    q = q.startAfterDocument(startAfter);
  }
  return q;
}

class HistoryState {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool loading;
  final bool loadingMore;
  final bool refreshing;
  final bool hasMore;
  final Object? error;

  const HistoryState({
    required this.docs,
    required this.loading,
    required this.loadingMore,
    required this.refreshing,
    required this.hasMore,
    required this.error,
  });

  HistoryState copyWith({
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs,
    bool? loading,
    bool? loadingMore,
    bool? refreshing,
    bool? hasMore,
    Object? error,
  }) {
    return HistoryState(
      docs: docs ?? this.docs,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(
          const HistoryState(
            docs: [],
            loading: true,
            loadingMore: false,
            refreshing: false,
            hasMore: true,
            error: null,
          ),
        );

  final FirebaseFirestore _firestore;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastTs;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastStr;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastNum;

  Future<void> refresh(DateTimeRange range) async {
    _lastTs = null;
    _lastStr = null;
    _lastNum = null;
    emit(
      state.copyWith(
        docs: const [],
        loading: true,
        loadingMore: false,
        refreshing: true,
        hasMore: true,
        error: null,
      ),
    );
    await _loadPage(range, reset: true);
  }

  Future<void> loadMore(DateTimeRange range) async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true, error: null));
    await _loadPage(range);
  }

  Future<void> _loadPage(DateTimeRange range, {bool reset = false}) async {
    try {
      final tsSnap = await _salesQuery(
        _firestore,
        range,
        stringRange: false,
        limit: kHistoryPageSize,
        startAfter: reset ? null : _lastTs,
      ).get();

      QuerySnapshot<Map<String, dynamic>>? strSnap;
      try {
        strSnap = await _salesQuery(
          _firestore,
          range,
          stringRange: true,
          limit: kHistoryPageSize,
          startAfter: reset ? null : _lastStr,
        ).get();
      } catch (_) {
        strSnap = null;
      }

      QuerySnapshot<Map<String, dynamic>>? numSnap;
      try {
        numSnap = await _salesQueryNum(
          _firestore,
          range,
          limit: kHistoryPageSize,
          startAfter: reset ? null : _lastNum,
        ).get();
      } catch (_) {
        numSnap = null;
      }

      if (tsSnap.docs.isNotEmpty) {
        _lastTs = tsSnap.docs.last;
      }
      if (strSnap != null && strSnap.docs.isNotEmpty) {
        _lastStr = strSnap.docs.last;
      }
      if (numSnap != null && numSnap.docs.isNotEmpty) {
        _lastNum = numSnap.docs.last;
      }

      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final d in state.docs) {
        byId[d.id] = d;
      }
      for (final d in tsSnap.docs) {
        byId[d.id] = d;
      }
      if (strSnap != null) {
        for (final d in strSnap.docs) {
          byId[d.id] = d;
        }
      }
      if (numSnap != null) {
        for (final d in numSnap.docs) {
          byId[d.id] = d;
        }
      }

      final list = byId.values.toList()
        ..sort((a, b) {
          final aDt = _createdAtOf(a.data());
          final bDt = _createdAtOf(b.data());
          return bDt.compareTo(aDt);
        });

      final hasMore =
          tsSnap.docs.length == kHistoryPageSize ||
          (strSnap?.docs.length == kHistoryPageSize) ||
          (numSnap?.docs.length == kHistoryPageSize);

      emit(
        state.copyWith(
          docs: list,
          loading: false,
          loadingMore: false,
          refreshing: false,
          hasMore: hasMore,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          loadingMore: false,
          refreshing: false,
          error: e,
        ),
      );
    }
  }
}

class DeferredState {
  final int count;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> unpaid;
  final bool loadingCount;
  final bool loadingUnpaid;
  final Object? countError;
  final Object? unpaidError;

  const DeferredState({
    required this.count,
    required this.unpaid,
    required this.loadingCount,
    required this.loadingUnpaid,
    required this.countError,
    required this.unpaidError,
  });

  DeferredState copyWith({
    int? count,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? unpaid,
    bool? loadingCount,
    bool? loadingUnpaid,
    Object? countError,
    Object? unpaidError,
  }) {
    return DeferredState(
      count: count ?? this.count,
      unpaid: unpaid ?? this.unpaid,
      loadingCount: loadingCount ?? this.loadingCount,
      loadingUnpaid: loadingUnpaid ?? this.loadingUnpaid,
      countError: countError,
      unpaidError: unpaidError,
    );
  }
}

class DeferredCubit extends Cubit<DeferredState> {
  DeferredCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(
          const DeferredState(
            count: 0,
            unpaid: [],
            loadingCount: true,
            loadingUnpaid: true,
            countError: null,
            unpaidError: null,
          ),
        ) {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _countSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unpaidSub;

  void _subscribe() {
    _countSub = _firestore
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) {
            final count =
                snap.docs.where((d) => (d.data()['paid'] ?? false) == false).length;
            emit(
              state.copyWith(
                count: count,
                loadingCount: false,
                countError: null,
              ),
            );
          },
          onError: (e, _) => emit(
            state.copyWith(loadingCount: false, countError: e),
          ),
        );

    _unpaidSub = _firestore
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) => emit(
            state.copyWith(
              unpaid: snap.docs,
              loadingUnpaid: false,
              unpaidError: null,
            ),
          ),
          onError: (e, _) => emit(
            state.copyWith(loadingUnpaid: false, unpaidError: e),
          ),
        );
  }

  @override
  Future<void> close() async {
    await _countSub?.cancel();
    await _unpaidSub?.cancel();
    return super.close();
  }
}
