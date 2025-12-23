import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'date_range_controller.dart';

/// ========= Deferred (badge) =========
/// Stream for unpaid deferred LIST (if you ever need it visually).
/// ????? ?????? ????? ??? ??????? (?? ?????? ?? ????)? ????? ???? ??????? ????????.
final unpaidDeferredStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      return FirebaseFirestore.instance
          .collection('sales')
          .where('is_deferred', isEqualTo: true)
          .where('paid', isEqualTo: false)
          .snapshots(includeMetadataChanges: true);
    });

/// Count provider using server aggregate (lighter than streaming all docs).
/// ????? ?????? ??????? ??? Aggregate Query (??? ????? ?? ????? ????).
///
final deferredCountStreamProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      /// Count provider using server aggregate (lighter than streaming all docs).
      /// ????? ?????? ??????? ??? Aggregate Query (??? ????? ?? ????? ????).
      .collection('sales')
      .where('is_deferred', isEqualTo: true)
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) => s.docs.where((d) => (d.data()['paid'] ?? false) == false).length,
      );
});

/// ========= History stream (bounded) =========
/// We strictly bound by start & end to avoid wide reads.
/// ?????? ????????? ?????? ?????? ????? ?????? ????????.
const int kHistoryStreamLimit = 500;

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
  DateTimeRange r, {
  required bool stringRange,
}) {
  final end = stringRange ? r.end.toUtc().toIso8601String() : r.end.toUtc();
  return FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isLessThan: end)
      .orderBy('created_at', descending: true)
      .limit(kHistoryStreamLimit);
}

Query<Map<String, dynamic>> _salesQueryNum(DateTimeRange r) {
  final endMs = r.end.toUtc().millisecondsSinceEpoch;
  return FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isLessThan: endMs)
      .orderBy('created_at', descending: true)
      .limit(kHistoryStreamLimit);
}

Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _mergeSalesStreams(
  DateTimeRange r,
) {
  final controller =
      StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
  QuerySnapshot<Map<String, dynamic>>? tsSnap;
  QuerySnapshot<Map<String, dynamic>>? strSnap;
  QuerySnapshot<Map<String, dynamic>>? numSnap;

  void emit() {
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    if (tsSnap != null) {
      for (final d in tsSnap!.docs) {
        byId[d.id] = d;
      }
    }
    if (strSnap != null) {
      for (final d in strSnap!.docs) {
        byId[d.id] = d;
      }
    }
    if (numSnap != null) {
      for (final d in numSnap!.docs) {
        byId[d.id] = d;
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) {
        final aDt = _createdAtOf(a.data());
        final bDt = _createdAtOf(b.data());
        return bDt.compareTo(aDt);
      });
    final trimmed = (list.length > kHistoryStreamLimit)
        ? list.sublist(0, kHistoryStreamLimit)
        : list;
    controller.add(trimmed);
  }

  final tsSub = _salesQuery(r, stringRange: false)
      .snapshots(includeMetadataChanges: false)
      .listen(
        (snap) {
          tsSnap = snap;
          emit();
        },
        onError: controller.addError,
      );

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? strSub;
  try {
    strSub = _salesQuery(r, stringRange: true)
        .snapshots(includeMetadataChanges: false)
        .listen(
          (snap) {
            strSnap = snap;
            emit();
          },
          onError: (_) {},
        );
  } catch (_) {
    strSub = null;
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? numSub;
  try {
    numSub = _salesQueryNum(r)
        .snapshots(includeMetadataChanges: false)
        .listen(
          (snap) {
            numSnap = snap;
            emit();
          },
          onError: (_) {},
        );
  } catch (_) {
    numSub = null;
  }

  controller.onCancel = () async {
    await tsSub.cancel();
    if (strSub != null) {
      await strSub!.cancel();
    }
    if (numSub != null) {
      await numSub!.cancel();
    }
    await controller.close();
  };

  return controller.stream;
}

/// Live stream for history within the selected range only.
/// ????? ??? ????? ???? ?????? ???.
final salesStreamProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
      final r = ref.watch(dateRangeProvider) ?? DateRangeController.today();
      return _mergeSalesStreams(r);
    });

/// Backward-compat name to avoid touching old imports.
