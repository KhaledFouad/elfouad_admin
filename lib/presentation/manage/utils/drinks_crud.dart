import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/services/archive/archive_service.dart';

import '../models/drink_row.dart';

Future<void> updateDrinkRow(
  DrinkRow drink, {
  String? name,
  String? unit,
  double? sellPrice,
  double? costPrice,
  String? image,
}) {
  final ref = FirebaseFirestore.instance.collection('drinks').doc(drink.id);
  final upd = <String, dynamic>{
    if (name != null) 'name': name,
    if (unit != null) 'unit': unit,
    if (sellPrice != null) 'sellPrice': sellPrice,
    if (costPrice != null) 'costPrice': costPrice,
    if (image != null) 'image': image,
  };
  return ref.update(upd);
}

Future<void> deleteDrink(String id) => archiveThenDelete(
      srcRef: FirebaseFirestore.instance.collection('drinks').doc(id),
      kind: 'drink',
      reason: 'manual_delete',
    );

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
