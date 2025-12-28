import 'package:cloud_firestore/cloud_firestore.dart';

class ExtraInventoryRow {
  final String id;
  final String name;
  final String category;
  final bool active;
  final double priceSell;
  final double costUnit;
  final double stockUnits;
  final String unit;
  final DocumentReference<Map<String, dynamic>> ref;

  const ExtraInventoryRow({
    required this.id,
    required this.name,
    required this.category,
    required this.active,
    required this.priceSell,
    required this.costUnit,
    required this.stockUnits,
    required this.unit,
    required this.ref,
  });
}
