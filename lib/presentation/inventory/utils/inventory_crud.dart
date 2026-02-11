import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/services/archive/archive_service.dart';

import '../models/inventory_row.dart';
import 'inventory_log.dart';

Future<void> updateInventoryRow(
  InventoryRow row, {
  String? name,
  String? variant,
  double? stockG,
  double? sellPerKg,
  double? costPerKg,
  double? minLevelG,
}) async {
  final data = <String, dynamic>{};
  if (name != null) data['name'] = name;
  if (variant != null) data['variant'] = variant;

  if (stockG != null) {
    if (row.isExtra) {
      data['stock_units'] = stockG;
    } else {
      data['stock'] = stockG;
    }
  }

  if (!row.isExtra) {
    if (sellPerKg != null) data['sellPricePerKg'] = sellPerKg;
    if (costPerKg != null) data['costPricePerKg'] = costPerKg;
    if (minLevelG != null) data['minLevel'] = minLevelG;
  } else {
    if (minLevelG != null) data['min_units'] = minLevelG;
  }

  await row.ref.update(data);

  final before = <String, dynamic>{
    'stock': row.stockG,
    'sell_per_kg': row.sellPerKg,
    'cost_per_kg': row.costPerKg,
  };
  final after = <String, dynamic>{
    'stock': stockG ?? row.stockG,
    'sell_per_kg': sellPerKg ?? row.sellPerKg,
    'cost_per_kg': costPerKg ?? row.costPerKg,
  };
  try {
    await logInventoryChange(
      action: 'update',
      collection: row.coll,
      itemId: row.id,
      name: name ?? row.name,
      variant: variant ?? row.variant,
      before: before,
      after: after,
      unit: 'g',
      source: 'inventory_edit',
    );
  } catch (_) {
    // ignore log failures
  }
}

Future<void> deleteInventoryRow(InventoryRow row) => archiveThenDelete(
  srcRef: row.ref,
  kind: 'inventory_row',
  reason: 'manual_delete',
);

Future<void> createInventoryRow({
  required bool isBlend,
  required String name,
  String variant = '',
  required double stockG,
  required double sellPerKg,
  required double costPerKg,
  double minLevelG = 0,
}) async {
  final col = FirebaseFirestore.instance.collection(
    isBlend ? 'blends' : 'singles',
  );
  final docRef = await col.add({
    'name': name,
    'variant': variant,
    'stock': stockG,
    'sellPricePerKg': sellPerKg,
    'costPricePerKg': costPerKg,
    'minLevel': minLevelG,
    'unit': 'g',
    'createdAt': DateTime.now().toUtc(),
  });

  try {
    await logInventoryChange(
      action: 'create',
      collection: isBlend ? 'blends' : 'singles',
      itemId: docRef.id,
      name: name,
      variant: variant,
      before: const <String, dynamic>{},
      after: {
        'stock': stockG,
        'sell_per_kg': sellPerKg,
        'cost_per_kg': costPerKg,
      },
      unit: 'g',
      source: 'inventory_create',
    );
  } catch (_) {
    // ignore log failures
  }
}
