// ignore_for_file: invalid_use_of_protected_member
part of '../add_item_sheet.dart';

/// Drink matrix synchronization and ingredient picker helpers.
extension _AddItemSheetDrinkHelpers on _AddItemSheetState {
  String _nextOptionId() => 'opt_${_optionSeq++}';

  String _priceKey(String variantId, String roastId) => '$variantId::$roastId';

  void _clearDrinkPrices() {
    for (final entry in _drinkPrices.values) {
      entry.dispose();
    }
    _drinkPrices.clear();
  }

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
        ? <String>[_AddItemSheetState._defaultVariantId]
        : _drinkVariants.map((e) => e.id).toList();
    final roastIds = _drinkRoasts.isEmpty
        ? <String>[_AddItemSheetState._defaultRoastId]
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

  _RoastUsageEntry _roastUsageFor(String roastId) {
    return _roastUsage.putIfAbsent(roastId, () => _RoastUsageEntry());
  }

  List<_DrinkPriceEntry> _orderedDrinkPrices() {
    if (_drinkVariants.isEmpty && _drinkRoasts.isEmpty) {
      return const [];
    }
    final variantIds = _drinkVariants.isEmpty
        ? <String>[_AddItemSheetState._defaultVariantId]
        : _drinkVariants.map((e) => e.id).toList();
    final roastIds = _drinkRoasts.isEmpty
        ? <String>[_AddItemSheetState._defaultRoastId]
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
    if (id == _AddItemSheetState._defaultVariantId) return '';
    for (final entry in _drinkVariants) {
      if (entry.id == id) return entry.name;
    }
    return '';
  }

  String _roastNameFor(String id) {
    if (id == _AddItemSheetState._defaultRoastId) return '';
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

  Future<InventoryRow?> _showIngredientPicker({
    required String coll,
    required List<InventoryRow> source,
    required bool loading,
  }) async {
    return showDialog<InventoryRow>(
      context: context,
      builder: (_) {
        final search = TextEditingController();
        return AlertDialog(
          title: Text(
            coll == 'singles'
                ? AppStrings.pickSingleItem
                : AppStrings.pickBlend,
          ),
          content: SizedBox(
            width: 460,
            height: 520,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: AppStrings.searchByNameVariant,
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => (context as Element).markNeedsBuild(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(
                          builder: (context) {
                            final q = search.text.trim().toLowerCase();
                            final filtered = q.isEmpty
                                ? source
                                : source.where((r) {
                                    final t = '${r.name} ${r.variant}'
                                        .toLowerCase();
                                    return t.contains(q);
                                  }).toList();
                            if (filtered.isEmpty) {
                              return const Center(
                                child: Text(AppStrings.noResults),
                              );
                            }
                            return ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final r = filtered[i];
                                return ListTile(
                                  title: Text(
                                    r.variant.isEmpty
                                        ? r.name
                                        : '${r.name} - ${r.variant}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Wrap(
                                    spacing: 8,
                                    children: [
                                      Text(
                                        AppStrings.stockGramsInline(r.stockG),
                                      ),
                                      Text(
                                        AppStrings.pricePerKgInline(
                                          r.sellPerKg,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => Navigator.pop(context, r),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.actionCancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDrinkIngredient({
    required String coll,
    required List<InventoryRow> source,
    required bool loading,
  }) async {
    final chosen = await _showIngredientPicker(
      coll: coll,
      source: source,
      loading: loading,
    );

    if (!mounted) return;
    if (chosen != null) {
      setState(() {
        _drinkIngredient = chosen;
        _drinkIngredientColl = coll;
      });
    }
  }
}
