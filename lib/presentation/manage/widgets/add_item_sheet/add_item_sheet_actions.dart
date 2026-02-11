// ignore_for_file: invalid_use_of_protected_member
part of '../add_item_sheet.dart';

/// Persist action handlers for all supported item types.
extension _AddItemSheetActions on _AddItemSheetState {
  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now().toUtc();
      final name = _name.text.trim();
      final posOrder = _intOrNull(_posOrder.text);

      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }

      if (_t == NewItemType.drink) {
        final variants = _drinkVariants.map((e) => e.name).toList();
        final roasts = _drinkRoasts.map((e) => e.name).toList();
        final hasVariants = variants.isNotEmpty;

        final hasMatrix = variants.isNotEmpty || roasts.isNotEmpty;
        final pricing = <Map<String, dynamic>>[];
        double baseSell = _num(_sellCup.text);
        double baseCost = _num(_costCup.text);

        if (hasMatrix) {
          _syncDrinkPricing();
          final variantIds = _drinkVariants.isEmpty
              ? <String>[_AddItemSheetState._defaultVariantId]
              : _drinkVariants.map((e) => e.id).toList();
          final roastIds = _drinkRoasts.isEmpty
              ? <String>[_AddItemSheetState._defaultRoastId]
              : _drinkRoasts.map((e) => e.id).toList();

          for (final vId in variantIds) {
            for (final rId in roastIds) {
              final row = _drinkPrices[_priceKey(vId, rId)];
              if (row == null) continue;
              final variant = _drinkVariants.isEmpty
                  ? ''
                  : _variantNameFor(vId);
              final roast = _drinkRoasts.isEmpty ? '' : _roastNameFor(rId);

              final entry = <String, dynamic>{
                'sellPrice': _num(row.sellCtrl.text),
                'costPrice': _num(row.costCtrl.text),
              };
              if (variant.isNotEmpty) entry['variant'] = variant;
              if (roast.isNotEmpty) entry['roast'] = roast;
              if (_drinkSpicedEnabled) {
                entry['spicedPriceDelta'] = _num(row.spicedSellCtrl.text);
                entry['spicedCostDelta'] = _num(row.spicedCostCtrl.text);
              }
              pricing.add(entry);
            }
          }

          if (pricing.isNotEmpty) {
            baseSell = _num(pricing.first['sellPrice']);
            baseCost = _num(pricing.first['costPrice']);
          }
        }

        final hasRoastUsage = roasts.isNotEmpty;
        final roastUsage = <Map<String, dynamic>>[];
        if (hasRoastUsage) {
          _syncRoastUsage();
          final missingItem = _drinkRoasts.any(
            (roast) => _roastUsage[roast.id]?.item == null,
          );
          if (missingItem) {
            setState(() => _showRoastUsageErrors = true);
            return;
          } else if (_showRoastUsageErrors) {
            setState(() => _showRoastUsageErrors = false);
          }
          for (final roast in _drinkRoasts) {
            final usage = _roastUsage[roast.id]!;
            final item = usage.item!;
            final entry = <String, dynamic>{
              'roast': roast.name,
              'usedItem': {
                'id': item.id,
                'name': item.name,
                'variant': item.variant,
                'collection': usage.coll,
              },
            };
            if (hasVariants) {
              final usedAmounts = <String, double>{};
              for (final variant in _drinkVariants) {
                usedAmounts[variant.name] = _num(
                  usage.gramsFor(variant.id).text,
                );
              }
              if (usedAmounts.isNotEmpty) {
                entry['usedAmounts'] = usedAmounts;
                entry['usedAmount'] = usedAmounts.values.first;
              }
            } else {
              entry['usedAmount'] = _num(usage.gramsCtrl.text);
            }
            roastUsage.add(entry);
          }
        }

        final usedAmount = _num(_drinkUsedGrams.text);
        final usedItem = _drinkIngredient == null
            ? null
            : {
                'id': _drinkIngredient!.id,
                'name': _drinkIngredient!.name,
                'variant': _drinkIngredient!.variant,
                'collection': _drinkIngredientColl,
              };

        final payload = <String, dynamic>{
          'name': name,
          'unit': 'cup',
          'sellPrice': baseSell,
          'costPrice': baseCost,
          'image': 'assets/drinks.jpg',
          'variants': variants,
          'roastLevels': roasts,
          'spicedEnabled': _drinkSpicedEnabled,
          'createdAt': now,
        };
        if (posOrder != null) {
          payload['posOrder'] = posOrder;
          payload['pos_order'] = posOrder;
        }

        if (!hasMatrix && _drinkSpicedEnabled) {
          payload['spicedPriceDelta'] = _num(_drinkSpicedPrice.text);
          payload['spicedCostDelta'] = _num(_drinkSpicedCost.text);
        }
        if (pricing.isNotEmpty) {
          payload['pricing'] = pricing;
        }
        if (hasRoastUsage && roastUsage.isNotEmpty) {
          payload['roastUsage'] = roastUsage;
        } else {
          if (usedItem != null) {
            payload['usedItem'] = usedItem;
          }
          if (hasVariants) {
            final usedByVariant = <String, double>{};
            for (final variant in _drinkVariants) {
              final grams = _num(_variantGrams[variant.id]?.text);
              if (grams > 0) {
                usedByVariant[variant.name] = grams;
              }
            }
            if (usedByVariant.isNotEmpty) {
              payload['usedAmountByVariant'] = usedByVariant;
              payload['usedAmount'] = usedByVariant.values.first;
            }
          } else if (usedAmount > 0) {
            payload['usedAmount'] = usedAmount;
          }
        }

        await db.collection('drinks').add(payload);
      } else if (_t == NewItemType.extra || _t == NewItemType.tahwiga) {
        final isTahwiga = _t == NewItemType.tahwiga;
        final category = _category.text.trim();
        await db.collection(isTahwiga ? 'tahwiga_options' : 'extras').add({
          'name': name,
          'category': category,
          'unit': _extraUnit.text.trim().isEmpty
              ? 'piece'
              : _extraUnit.text.trim(),
          // Tahwiga no longer uses stock tracking on create.
          'stock_units': isTahwiga ? 0.0 : _num(_stock.text),
          'price_sell': _num(_extraPrice.text),
          'cost_unit': _num(_extraCost.text),
          'active': _extraActive,
          'type': isTahwiga ? 'tahwiga' : 'extra',
          if (isTahwiga) 'is_tahwiga': true,
          if (!isTahwiga) 'is_extra': true,
          'created_at': now,
          'updated_at': now,
          if (posOrder != null) 'posOrder': posOrder,
          if (posOrder != null) 'pos_order': posOrder,
        });
      } else {
        final col = _t == NewItemType.single ? 'singles' : 'blends';
        final spicePrice = _itemSpicedEnabled
            ? _num(_spicePricePerKg.text)
            : 0.0;
        final spiceCost = _itemSpicedEnabled ? _num(_spiceCostPerKg.text) : 0.0;
        final selectedExtraIds = _normalizedSelectedExtraIds();
        if (_itemExtrasEnabled && selectedExtraIds.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.additionsRequiredPrompt)),
          );
          return;
        }
        final selectedExtraOptions = _selectedExtrasPayload(selectedExtraIds);

        if (_itemRoasts.isEmpty) {
          final baseSell = _num(_baseSellPerKg.text);
          final baseCost = _num(_baseCostPerKg.text);

          final payload = <String, dynamic>{
            'name': name,
            'variant': '',
            'unit': 'g',
            'stock': _num(_stock.text),
            'minLevel': 0,
            'sellPricePerKg': baseSell,
            'costPricePerKg': baseCost,
            'spicedEnabled': _itemSpicedEnabled,
            'spicePricePerKg': spicePrice,
            'spiceCostPerKg': spiceCost,
            'spicesPrice': spicePrice,
            'spicesCost': spiceCost,
            if (_itemExtrasEnabled) 'extrasEnabled': true,
            if (_itemExtrasEnabled) 'extraOptionIds': selectedExtraIds,
            if (_itemExtrasEnabled) 'extraOptions': selectedExtraOptions,
            'image': col == 'singles'
                ? 'assets/singles.jpg'
                : 'assets/blends.jpg',
            'createdAt': now,
            if (posOrder != null) 'posOrder': posOrder,
            if (posOrder != null) 'pos_order': posOrder,
          };
          final docRef = await db.collection(col).add(payload);
          await _logInventoryCreate(
            collection: col,
            id: docRef.id,
            name: name,
            variant: '',
            stock: _num(_stock.text),
            sellPerKg: baseSell,
            costPerKg: baseCost,
          );
        } else {
          final batch = db.batch();
          final logEntries = <Map<String, dynamic>>[];
          for (final entry in _itemRoasts) {
            final docRef = db.collection(col).doc();
            final payload = <String, dynamic>{
              'name': name,
              'variant': entry.name,
              'unit': 'g',
              'stock': _num(entry.stockCtrl.text),
              'minLevel': 0,
              'sellPricePerKg': _num(entry.sellCtrl.text),
              'costPricePerKg': _num(entry.costCtrl.text),
              'spicedEnabled': _itemSpicedEnabled,
              'spicePricePerKg': spicePrice,
              'spiceCostPerKg': spiceCost,
              'spicesPrice': spicePrice,
              'spicesCost': spiceCost,
              if (_itemExtrasEnabled) 'extrasEnabled': true,
              if (_itemExtrasEnabled) 'extraOptionIds': selectedExtraIds,
              if (_itemExtrasEnabled) 'extraOptions': selectedExtraOptions,
              'image': col == 'singles'
                  ? 'assets/singles.jpg'
                  : 'assets/blends.jpg',
              'createdAt': now,
              if (posOrder != null) 'posOrder': posOrder,
              if (posOrder != null) 'pos_order': posOrder,
            };
            batch.set(docRef, payload);
            logEntries.add({
              'id': docRef.id,
              'variant': entry.name,
              'stock': _num(entry.stockCtrl.text),
              'sell': _num(entry.sellCtrl.text),
              'cost': _num(entry.costCtrl.text),
            });
          }
          await batch.commit();
          for (final entry in logEntries) {
            await _logInventoryCreate(
              collection: col,
              id: entry['id'] as String,
              name: name,
              variant: (entry['variant'] ?? '').toString(),
              stock: _num(entry['stock']),
              sellPerKg: _num(entry['sell']),
              costPerKg: _num(entry['cost']),
            );
          }
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
