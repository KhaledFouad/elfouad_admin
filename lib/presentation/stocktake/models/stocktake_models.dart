import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/inventory/models/extra_inventory_row.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';
import 'package:elfouad_admin/presentation/stocktake/utils/stocktake_utils.dart';

enum StocktakeMode { record, log }

enum StocktakeFilter { all, singles, blends, extras }

enum StocktakeKind { single, blend, extra }

class StocktakeItem {
  final String key;
  final String id;
  final String name;
  final String variant;
  final String category;
  final String unit;
  final double current;
  final StocktakeKind kind;
  final DocumentReference<Map<String, dynamic>> ref;

  const StocktakeItem({
    required this.key,
    required this.id,
    required this.name,
    required this.variant,
    required this.category,
    required this.unit,
    required this.current,
    required this.kind,
    required this.ref,
  });

  factory StocktakeItem.fromInventory(
    InventoryRow row, {
    required String unit,
  }) {
    final isSingle = row.coll == 'singles';
    return StocktakeItem(
      key: '${row.coll}:${row.id}',
      id: row.id,
      name: row.name,
      variant: row.variant,
      category: '',
      unit: unit,
      current: row.stockG,
      kind: isSingle ? StocktakeKind.single : StocktakeKind.blend,
      ref: row.ref,
    );
  }

  factory StocktakeItem.fromExtra(ExtraInventoryRow row) {
    return StocktakeItem(
      key: 'extra:${row.id}',
      id: row.id,
      name: row.name,
      variant: '',
      category: row.category,
      unit: row.unit,
      current: row.stockUnits,
      kind: StocktakeKind.extra,
      ref: row.ref,
    );
  }

  bool get isExtra => kind == StocktakeKind.extra;

  String get title => composeStocktakeTitle(name, variant, category);

  String get kindName {
    switch (kind) {
      case StocktakeKind.single:
        return 'single';
      case StocktakeKind.blend:
        return 'blend';
      case StocktakeKind.extra:
        return 'extra';
    }
  }
}

class StocktakeChange {
  final StocktakeItem item;
  final double counted;
  final double diff;

  const StocktakeChange({
    required this.item,
    required this.counted,
    required this.diff,
  });
}
