import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final drinksStreamProvider = StreamProvider<List<DrinkRow>>((ref) async* {
  final q = FirebaseFirestore.instance.collection('drinks').orderBy('name');
  yield* q.snapshots().map((s) => s.docs.map(_fromDoc).toList());
});

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
