import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DrinkRow {
  final String id;
  final String name;
  final String unit; // cup/bottle ...
  final double sellPrice;
  final double costPrice;
  final String image;
  const DrinkRow({
    required this.id,
    required this.name,
    required this.unit,
    required this.sellPrice,
    required this.costPrice,
    required this.image,
  });
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

DrinkRow _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data();
  return DrinkRow(
    id: d.id,
    name: (m['name'] ?? '').toString(),
    unit: (m['unit'] ?? 'cup').toString(),
    sellPrice: _d(m['sellPrice']),
    costPrice: _d(m['costPrice']),
    image: (m['image'] ?? '').toString(),
  );
}

class DrinksState {
  final List<DrinkRow> items;
  final bool loading;
  final Object? error;

  const DrinksState({
    required this.items,
    required this.loading,
    required this.error,
  });

  DrinksState copyWith({
    List<DrinkRow>? items,
    bool? loading,
    Object? error,
  }) {
    return DrinksState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class DrinksCubit extends Cubit<DrinksState> {
  DrinksCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(const DrinksState(items: [], loading: true, error: null)) {
    _sub = _firestore
        .collection('drinks')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList())
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

Future<void> updateDrinkRow(
  DrinkRow d, {
  String? name,
  String? unit,
  double? sellPrice,
  double? costPrice,
  String? image,
}) {
  final ref = FirebaseFirestore.instance.collection('drinks').doc(d.id);
  final upd = <String, dynamic>{
    if (name != null) 'name': name,
    if (unit != null) 'unit': unit,
    if (sellPrice != null) 'sellPrice': sellPrice,
    if (costPrice != null) 'costPrice': costPrice,
    if (image != null) 'image': image,
  };
  return ref.update(upd);
}

Future<void> deleteDrink(String id) =>
    FirebaseFirestore.instance.collection('drinks').doc(id).delete();

Future<void> createDrink({
  required String name,
  String unit = 'cup',
  required double sellPrice,
  required double costPrice,
  String image = 'assets/drinks.jpg',
}) async {
  final ref = FirebaseFirestore.instance.collection('drinks').doc();
  await ref.set({
    'name': name,
    'unit': unit,
    'sellPrice': sellPrice,
    'costPrice': costPrice,
    'image': image,
    'createdAt': DateTime.now().toUtc(),
  });
}
