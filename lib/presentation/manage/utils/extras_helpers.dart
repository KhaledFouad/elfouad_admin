import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/extra_row.dart';

double parseExtraNumber(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }
  return 0.0;
}

ExtraRow extraRowFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return ExtraRow(
    id: doc.id,
    name: (data['name'] ?? '').toString(),
    active: (data['active'] ?? true) == true,
    category: (data['category'] ?? '').toString(),
    priceSell: parseExtraNumber(data['price_sell'] ?? data['priceSell']),
    costUnit: parseExtraNumber(data['cost_unit'] ?? data['costUnit']),
    stockUnits: parseExtraNumber(data['stock_units'] ?? data['stockUnits']),
    unit: (data['unit'] ?? '').toString(),
  );
}
