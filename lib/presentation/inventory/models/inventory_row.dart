import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryRow {
  final String id;
  final String name;
  final String variant;
  final double stockG;
  final double minLevelG;
  final double sellPerKg;
  final double costPerKg;
  final String coll;
  final DocumentReference<Map<String, dynamic>> ref;

  const InventoryRow({
    required this.id,
    required this.name,
    required this.variant,
    required this.stockG,
    required this.minLevelG,
    required this.sellPerKg,
    required this.costPerKg,
    required this.coll,
    required this.ref,
  });

  bool get isSingle => coll == 'singles';
  bool get isBlend => coll == 'blends';
  bool get isExtra => false;
}
