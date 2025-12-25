import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExtraRow {
  final String id;
  final String name;
  final bool active;
  final String category;
  final double priceSell;
  final double costUnit;
  final double stockUnits;
  final String unit;

  const ExtraRow({
    required this.id,
    required this.name,
    required this.active,
    required this.category,
    required this.priceSell,
    required this.costUnit,
    required this.stockUnits,
    required this.unit,
  });
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

ExtraRow _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data();
  return ExtraRow(
    id: d.id,
    name: (m['name'] ?? '').toString(),
    active: (m['active'] ?? true) == true,
    category: (m['category'] ?? '').toString(),
    priceSell: _d(m['price_sell'] ?? m['priceSell']),
    costUnit: _d(m['cost_unit'] ?? m['costUnit']),
    stockUnits: _d(m['stock_units'] ?? m['stockUnits']),
    unit: (m['unit'] ?? '').toString(),
  );
}

class ExtrasState {
  final List<ExtraRow> items;
  final bool loading;
  final Object? error;

  const ExtrasState({
    required this.items,
    required this.loading,
    required this.error,
  });

  ExtrasState copyWith({
    List<ExtraRow>? items,
    bool? loading,
    Object? error,
  }) {
    return ExtrasState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class ExtrasCubit extends Cubit<ExtrasState> {
  ExtrasCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(const ExtrasState(items: [], loading: true, error: null)) {
    _sub = _firestore
        .collection('extras')
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
  StreamSubscription<List<ExtraRow>>? _sub;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

Future<void> deleteExtra(String id) =>
    FirebaseFirestore.instance.collection('extras').doc(id).delete();
