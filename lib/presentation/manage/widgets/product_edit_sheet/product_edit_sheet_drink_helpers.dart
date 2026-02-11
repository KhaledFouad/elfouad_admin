part of '../product_edit_sheet.dart';

/// Drink pricing and roast usage synchronization helpers.
extension _ProductEditSheetDrinkHelpers on _ProductEditSheetState {
  void _syncVariantUsage() {
    final activeIds = _drinkVariants.map((e) => e.id).toSet();
    for (final id in activeIds) {
      _variantGrams.putIfAbsent(id, () => TextEditingController());
    }
    final removeIds = _variantGrams.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in removeIds) {
      _variantGrams[id]?.dispose();
      _variantGrams.remove(id);
    }
    for (final entry in _roastUsage.values) {
      entry.syncVariants(activeIds);
    }
  }

  void _syncDrinkPricing() {
    _syncVariantUsage();
    if (_drinkVariants.isEmpty && _drinkRoasts.isEmpty) {
      _clearDrinkPrices();
      return;
    }

    final variantIds = _drinkVariants.isEmpty
        ? <String>[_ProductEditSheetState._defaultVariantId]
        : _drinkVariants.map((e) => e.id).toList();
    final roastIds = _drinkRoasts.isEmpty
        ? <String>[_ProductEditSheetState._defaultRoastId]
        : _drinkRoasts.map((e) => e.id).toList();

    final wantedKeys = <String>{};
    for (final v in variantIds) {
      for (final r in roastIds) {
        final key = _priceKey(v, r);
        wantedKeys.add(key);
        _drinkPrices.putIfAbsent(
          key,
          () => _DrinkPriceEntry(variantId: v, roastId: r),
        );
      }
    }

    final removeKeys = _drinkPrices.keys
        .where((k) => !wantedKeys.contains(k))
        .toList();
    for (final key in removeKeys) {
      _drinkPrices[key]?.dispose();
      _drinkPrices.remove(key);
    }
  }

  void _clearDrinkPrices() {
    for (final entry in _drinkPrices.values) {
      entry.dispose();
    }
    _drinkPrices.clear();
  }

  void _syncRoastUsage() {
    final activeIds = _drinkRoasts.map((e) => e.id).toSet();
    for (final id in activeIds) {
      _roastUsage.putIfAbsent(id, () => _RoastUsageEntry());
    }
    final removeIds = _roastUsage.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in removeIds) {
      _roastUsage[id]?.dispose();
      _roastUsage.remove(id);
    }
    final variantIds = _drinkVariants.map((e) => e.id).toSet();
    for (final entry in _roastUsage.values) {
      entry.syncVariants(variantIds);
    }
  }

  void _applyDrinkPricing(List<Map<String, dynamic>> pricing) {
    if (pricing.isEmpty || _drinkPrices.isEmpty) return;
    for (final entry in _drinkPrices.values) {
      final variant = _variantNameFor(entry.variantId);
      final roast = _roastNameFor(entry.roastId);
      final match = _findPricing(pricing, variant, roast);
      if (match == null) continue;
      entry.sellCtrl.text = _format(_num(match['sellPrice']));
      entry.costCtrl.text = _format(_num(match['costPrice']));
      entry.spicedSellCtrl.text = _format(_num(match['spicedPriceDelta']));
      entry.spicedCostCtrl.text = _format(_num(match['spicedCostDelta']));
    }
  }

  void _applyRoastUsage(List<Map<String, dynamic>> usage) {
    if (usage.isEmpty || _drinkRoasts.isEmpty) return;
    for (final entry in usage) {
      final roastName = (entry['roast'] ?? '').toString();
      final roast = _findRoastByName(roastName);
      if (roast == null) continue;
      final usageEntry = _roastUsageFor(roast.id);
      final usedAmounts = _mapOrNull(entry['usedAmounts']);
      if (usedAmounts != null && usedAmounts.isNotEmpty) {
        if (_drinkVariants.isNotEmpty) {
          for (final usedEntry in usedAmounts.entries) {
            final variant = _findVariantByName(usedEntry.key);
            if (variant == null) continue;
            usageEntry.gramsFor(variant.id).text = _format(
              _num(usedEntry.value),
            );
          }
        } else {
          usageEntry.gramsCtrl.text = _format(_num(usedAmounts.values.first));
        }
      } else {
        final usedAmount = _num(entry['usedAmount']);
        if (_drinkVariants.isNotEmpty) {
          if (usedAmount > 0) {
            for (final variant in _drinkVariants) {
              usageEntry.gramsFor(variant.id).text = _format(usedAmount);
            }
          }
        } else if (usedAmount > 0) {
          usageEntry.gramsCtrl.text = _format(usedAmount);
        }
      }
      final usedItem = _mapOrNull(entry['usedItem']);
      if (usedItem != null) {
        usageEntry.item = _inventoryFromMap(usedItem);
        usageEntry.coll = usedItem['collection']?.toString();
      }
    }
  }

  void _applyVariantUsage(Map<String, dynamic> usage) {
    if (usage.isEmpty || _drinkVariants.isEmpty) return;
    for (final entry in usage.entries) {
      final variant = _findVariantByName(entry.key);
      if (variant == null) continue;
      _variantGrams[variant.id]?.text = _format(_num(entry.value));
    }
  }

  _RoastUsageEntry _roastUsageFor(String roastId) {
    return _roastUsage.putIfAbsent(roastId, () => _RoastUsageEntry());
  }

  List<_DrinkPriceEntry> _orderedDrinkPrices() {
    if (_drinkVariants.isEmpty && _drinkRoasts.isEmpty) {
      return const [];
    }
    final variantIds = _drinkVariants.isEmpty
        ? <String>[_ProductEditSheetState._defaultVariantId]
        : _drinkVariants.map((e) => e.id).toList();
    final roastIds = _drinkRoasts.isEmpty
        ? <String>[_ProductEditSheetState._defaultRoastId]
        : _drinkRoasts.map((e) => e.id).toList();

    final rows = <_DrinkPriceEntry>[];
    for (final v in variantIds) {
      for (final r in roastIds) {
        final row = _drinkPrices[_priceKey(v, r)];
        if (row != null) rows.add(row);
      }
    }
    return rows;
  }

  String _variantNameFor(String id) {
    if (id == _ProductEditSheetState._defaultVariantId) return '';
    for (final entry in _drinkVariants) {
      if (entry.id == id) return entry.name;
    }
    return '';
  }

  String _roastNameFor(String id) {
    if (id == _ProductEditSheetState._defaultRoastId) return '';
    for (final entry in _drinkRoasts) {
      if (entry.id == id) return entry.name;
    }
    return '';
  }

  String _priceLabelFor(_DrinkPriceEntry row) {
    final variant = _variantNameFor(row.variantId);
    final roast = _roastNameFor(row.roastId);
    final hasVariants = _drinkVariants.isNotEmpty;
    final hasRoasts = _drinkRoasts.isNotEmpty;
    if (hasVariants && hasRoasts) {
      final v = variant.isEmpty ? AppStrings.unnamedLabel : variant;
      final r = roast.isEmpty ? AppStrings.unnamedLabel : roast;
      return '$v - $r';
    }
    if (hasVariants) {
      return variant.isEmpty ? AppStrings.unnamedLabel : variant;
    }
    if (hasRoasts) {
      return roast.isEmpty ? AppStrings.unnamedLabel : roast;
    }
    return AppStrings.drinkPricingLabel;
  }

  String _nextOptionId() => 'opt_${_optionSeq++}';

  String _priceKey(String variantId, String roastId) => '$variantId::$roastId';

  _OptionEntry? _findVariantByName(String name) {
    for (final entry in _drinkVariants) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  _OptionEntry? _findRoastByName(String name) {
    for (final entry in _drinkRoasts) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  Map<String, dynamic>? _findPricing(
    List<Map<String, dynamic>> pricing,
    String variant,
    String roast,
  ) {
    for (final entry in pricing) {
      final entryVariant = (entry['variant'] ?? '').toString();
      final entryRoast = (entry['roast'] ?? '').toString();
      if (entryVariant == variant && entryRoast == roast) {
        return entry;
      }
    }
    if (variant.isEmpty && roast.isEmpty && pricing.length == 1) {
      return pricing.first;
    }
    return null;
  }

  InventoryRow _inventoryFromMap(Map<String, dynamic> data) {
    final id = (data['id'] ?? '').toString();
    final name = (data['name'] ?? '').toString();
    final variant = (data['variant'] ?? '').toString();
    final coll = (data['collection'] ?? '').toString();
    final refColl = coll.isEmpty ? 'singles' : coll;
    return InventoryRow(
      id: id,
      name: name,
      variant: variant,
      stockG: 0,
      minLevelG: 0,
      sellPerKg: 0,
      costPerKg: 0,
      coll: coll,
      ref: FirebaseFirestore.instance.collection(refColl).doc(id),
    );
  }
}
