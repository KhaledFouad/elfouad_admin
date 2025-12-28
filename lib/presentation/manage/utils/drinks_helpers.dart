import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/drink_row.dart';

double parseDrinkNumber(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

DrinkRow drinkRowFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return DrinkRow(
    id: doc.id,
    name: (data['name'] ?? '').toString(),
    unit: (data['unit'] ?? 'cup').toString(),
    sellPrice: parseDrinkNumber(data['sellPrice']),
    costPrice: parseDrinkNumber(data['costPrice']),
    image: (data['image'] ?? '').toString(),
  );
}
