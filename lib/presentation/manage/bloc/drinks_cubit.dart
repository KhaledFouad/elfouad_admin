import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/drink_row.dart';
import '../utils/drinks_helpers.dart';
import 'drinks_state.dart';

class DrinksCubit extends Cubit<DrinksState> {
  DrinksCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(const DrinksState(items: [], loading: true, error: null)) {
    _sub = _firestore
        .collection('drinks')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(drinkRowFromDoc).toList())
        .listen(
          (items) => emit(
            state.copyWith(items: items, loading: false, error: null),
          ),
          onError: (e, _) => emit(
            state.copyWith(loading: false, error: e),
          ),
        );
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<List<DrinkRow>>? _sub;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
