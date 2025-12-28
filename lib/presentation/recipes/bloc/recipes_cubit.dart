import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/recipe_list_item.dart';
import 'recipes_state.dart';

class RecipesCubit extends Cubit<RecipesState> {
  RecipesCubit({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        super(const RecipesState(items: [], loading: true, error: null)) {
    _subscribe();
  }

  final FirebaseFirestore _db;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void _subscribe() {
    _sub?.cancel();
    _sub = _db
        .collection('recipes')
        .orderBy('name')
        .snapshots()
        .listen(
      (snap) {
        final items = snap.docs.map(RecipeListItem.fromSnapshot).toList();
        emit(state.copyWith(items: items, loading: false, error: null));
      },
      onError: (e, _) => emit(state.copyWith(loading: false, error: e)),
    );
  }

  Future<void> deleteRecipe(String id) =>
      _db.collection('recipes').doc(id).delete();

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
