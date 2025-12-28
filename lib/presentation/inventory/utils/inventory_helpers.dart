import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/extra_inventory_row.dart';
import '../models/inventory_row.dart';

double parseInventoryNumber(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

double stockGramsFrom(Map<String, dynamic> data) {
  final keys = [
    'stock',
    'stock_grams',
    'available_grams',
    'in_stock_grams',
    'grams_in_stock',
  ];
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return 0.0;
}

InventoryRow inventoryRowFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final sell = parseInventoryNumber(
    data['sellPricePerKg'] ?? data['sellPerKg'] ?? data['sell_price_per_kg'],
  );
  final cost = parseInventoryNumber(
    data['costPricePerKg'] ?? data['costPerKg'] ?? data['cost_price_per_kg'],
  );
  return InventoryRow(
    id: doc.id,
    name: '${data['name'] ?? ''}',
    variant: '${data['variant'] ?? ''}',
    stockG: stockGramsFrom(data),
    minLevelG: parseInventoryNumber(data['minLevel']),
    sellPerKg: sell,
    costPerKg: cost,
    coll: doc.reference.parent.id,
    ref: doc.reference,
  );
}

double extraNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9.,-]'), '');
      final parsed = double.tryParse(sanitized.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

String extraString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

bool extraBool(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
  }
  return true;
}

ExtraInventoryRow extraInventoryRowFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  return ExtraInventoryRow(
    id: doc.id,
    name: extraString(data, ['name', 'title', 'label']),
    category: extraString(data, ['category', 'type', 'group']),
    active: extraBool(data, ['active', 'isActive', 'enabled']),
    priceSell: extraNumber(data, [
      'price_sell',
      'priceSell',
      'sellPrice',
      'sell_price',
      'price',
    ]),
    costUnit: extraNumber(data, [
      'cost_unit',
      'costUnit',
      'costPrice',
      'cost',
      'purchase_price',
    ]),
    stockUnits: extraNumber(data, [
      'stock_units',
      'stock',
      'quantity',
      'available',
      'inventory',
    ]),
    unit: extraString(data, ['unit', 'unitName', 'unit_name']),
    ref: doc.reference,
  );
}

List<InventoryRow> sortByNameVariant(Iterable<InventoryRow> items) {
  final list = items.toList();
  list.sort((a, b) {
    final name = a.name.compareTo(b.name);
    if (name != 0) return name;
    return a.variant.compareTo(b.variant);
  });
  return list;
}
