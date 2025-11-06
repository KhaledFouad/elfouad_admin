import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final extrasStreamProvider = StreamProvider<List<ExtraRow>>((ref) async* {
  final q = FirebaseFirestore.instance.collection('extras').orderBy('name');
  yield* q.snapshots().map((s) => s.docs.map(_fromDoc).toList());
});

Future<void> deleteExtra(String id) =>
    FirebaseFirestore.instance.collection('extras').doc(id).delete();
