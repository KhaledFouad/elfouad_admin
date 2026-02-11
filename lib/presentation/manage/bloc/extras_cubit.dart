import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/extra_row.dart';
import '../utils/extras_helpers.dart';
import 'extras_state.dart';

class ExtrasCubit extends Cubit<ExtrasState> {
  ExtrasCubit({FirebaseFirestore? firestore, String collectionPath = 'extras'})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _collectionPath = collectionPath,
      super(const ExtrasState(items: [], loading: true, error: null)) {
    _sub = _firestore
        .collection(_collectionPath)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(extraRowFromDoc).toList())
        .listen(
          (items) =>
              emit(state.copyWith(items: items, loading: false, error: null)),
          onError: (e, _) => emit(state.copyWith(loading: false, error: e)),
        );
  }

  final FirebaseFirestore _firestore;
  final String _collectionPath;
  StreamSubscription<List<ExtraRow>>? _sub;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
