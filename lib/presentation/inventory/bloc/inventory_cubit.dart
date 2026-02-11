import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/extra_inventory_row.dart';
import '../models/inventory_row.dart';
import '../models/inventory_tab.dart';
import '../utils/inventory_helpers.dart';
import 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      super(
        const InventoryState(
          tab: InventoryTab.all,
          singles: [],
          blends: [],
          extras: [],
          tahwiga: [],
          loadingSingles: true,
          loadingBlends: true,
          loadingExtras: true,
          loadingTahwiga: true,
          error: null,
        ),
      ) {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<List<InventoryRow>>? _singlesSub;
  StreamSubscription<List<InventoryRow>>? _blendsSub;
  StreamSubscription<List<ExtraInventoryRow>>? _extrasSub;
  StreamSubscription<List<ExtraInventoryRow>>? _tahwigaSub;

  void setTab(InventoryTab tab) => emit(state.copyWith(tab: tab));

  void _subscribe() {
    _singlesSub = _firestore
        .collection('singles')
        .orderBy('name')
        .snapshots()
        .map((snap) => sortByNameVariant(snap.docs.map(inventoryRowFromDoc)))
        .listen(
          (rows) => emit(
            state.copyWith(singles: rows, loadingSingles: false, error: null),
          ),
          onError: (e, _) =>
              emit(state.copyWith(loadingSingles: false, error: e)),
        );

    _blendsSub = _firestore
        .collection('blends')
        .orderBy('name')
        .snapshots()
        .map((snap) => sortByNameVariant(snap.docs.map(inventoryRowFromDoc)))
        .listen(
          (rows) => emit(
            state.copyWith(blends: rows, loadingBlends: false, error: null),
          ),
          onError: (e, _) =>
              emit(state.copyWith(loadingBlends: false, error: e)),
        );

    _extrasSub = _firestore
        .collection('extras')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(extraInventoryRowFromDoc).toList())
        .listen(
          (rows) => emit(
            state.copyWith(extras: rows, loadingExtras: false, error: null),
          ),
          onError: (e, _) =>
              emit(state.copyWith(loadingExtras: false, error: e)),
        );

    _tahwigaSub = _firestore
        .collection('tahwiga_options')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(extraInventoryRowFromDoc).toList())
        .listen(
          (rows) => emit(
            state.copyWith(tahwiga: rows, loadingTahwiga: false, error: null),
          ),
          onError: (e, _) =>
              emit(state.copyWith(loadingTahwiga: false, error: e)),
        );
  }

  @override
  Future<void> close() async {
    await _singlesSub?.cancel();
    await _blendsSub?.cancel();
    await _extrasSub?.cancel();
    await _tahwigaSub?.cancel();
    return super.close();
  }
}
