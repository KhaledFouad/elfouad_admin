import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/data/repo/sales_history_repository.dart';
import 'package:elfouad_admin/presentation/archive/bloc/archive_trash_state.dart';
import 'package:elfouad_admin/presentation/archive/models/archive_entry.dart';
import 'package:elfouad_admin/services/archive/archive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArchiveTrashCubit extends Cubit<ArchiveTrashState> {
  ArchiveTrashCubit({
    FirebaseFirestore? firestore,
    SalesHistoryRepository? salesRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _salesRepository =
           salesRepository ??
           SalesHistoryRepository(firestore ?? FirebaseFirestore.instance),
       super(ArchiveTrashState.initial()) {
    _subscribe(state.range);
  }

  final FirebaseFirestore _firestore;
  final SalesHistoryRepository _salesRepository;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void _subscribe(DateTimeRange range) {
    _sub?.cancel();
    emit(state.copyWith(loading: true, error: null, range: range));
    final query = _firestore
        .collection(archiveBinCollection)
        .where('archived_at', isGreaterThanOrEqualTo: range.start)
        .where('archived_at', isLessThan: range.end)
        .orderBy('archived_at', descending: true);
    _sub = query.snapshots().listen((snap) {
      final entries = snap.docs.map(ArchiveEntry.fromSnapshot).toList();
      emit(state.copyWith(loading: false, error: null, entries: entries));
    }, onError: (e, _) => emit(state.copyWith(loading: false, error: e)));
  }

  void setFilter(ArchiveFilter filter) {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter));
  }

  void setRange(DateTimeRange range) {
    final current = state.range;
    if (_sameRange(current, range)) return;
    _subscribe(range);
  }

  Future<void> restoreEntry(ArchiveEntry entry) async {
    if (state.restoringIds.contains(entry.id)) return;
    _setRestoring(entry.id, true);
    try {
      if (entry.kind == 'sale') {
        await _salesRepository.restoreSaleFromArchive(entry.ref);
      } else {
        await restoreFromArchive(archiveRef: entry.ref);
      }
    } finally {
      _setRestoring(entry.id, false);
    }
  }

  void _setRestoring(String id, bool active) {
    final next = Set<String>.from(state.restoringIds);
    if (active) {
      next.add(id);
    } else {
      next.remove(id);
    }
    emit(state.copyWith(restoringIds: next));
  }

  bool _sameRange(DateTimeRange a, DateTimeRange b) {
    return a.start == b.start && a.end == b.end;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
