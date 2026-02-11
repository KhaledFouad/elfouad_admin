// ignore_for_file: invalid_use_of_protected_member
part of '../product_edit_sheet.dart';

/// Persist actions for bean and drink product updates.
extension _ProductEditSheetActions on _ProductEditSheetState {
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = _isDrinks ? await _saveDrink() : await _saveBean();
      if (!ok || !mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.saveSuccess)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.saveFailedAccented(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _saveBean() async {
    final beforeName = (_data['name'] ?? '').toString().trim();
    final beforeVariant = (_data['variant'] ?? '').toString().trim();
    final before = <String, dynamic>{
      'stock': _num(_data['stock']),
      'sell_per_kg': _num(_data['sellPricePerKg']),
      'cost_per_kg': _num(_data['costPricePerKg']),
    };

    final upd = <String, dynamic>{
      'name': _name.text.trim(),
      'variant': _variant.text.trim(),
    };
    _applyPosOrder(upd);
    if (_unit.text.trim().isNotEmpty) {
      upd['unit'] = _unit.text.trim();
    }
    upd['stock'] = _num(_stock.text);
    upd['sellPricePerKg'] = _num(_sellPerKg.text);
    upd['costPricePerKg'] = _num(_costPerKg.text);

    upd['spicedEnabled'] = _beanSpicedEnabled;
    final spicePrice = _beanSpicedEnabled ? _num(_spicePricePerKg.text) : 0.0;
    final spiceCost = _beanSpicedEnabled ? _num(_spiceCostPerKg.text) : 0.0;
    upd['spicePricePerKg'] = spicePrice;
    upd['spiceCostPerKg'] = spiceCost;
    upd['spicesPrice'] = spicePrice;
    upd['spicesCost'] = spiceCost;
    upd['ginsengEnabled'] = FieldValue.delete();
    upd['ginsengPricePerKg'] = FieldValue.delete();
    upd['ginsengCostPerKg'] = FieldValue.delete();

    final selectedExtraIds = _normalizedBeanExtraIds();
    if (_beanExtrasEnabled && selectedExtraIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.additionsRequiredPrompt)),
        );
      }
      return false;
    }
    if (_beanExtrasEnabled) {
      upd['extrasEnabled'] = true;
      upd['extraOptionIds'] = selectedExtraIds;
      upd['extraOptions'] = _selectedExtrasPayload(selectedExtraIds);
    } else {
      upd['extrasEnabled'] = FieldValue.delete();
      upd['extraOptionIds'] = FieldValue.delete();
      upd['extraOptions'] = FieldValue.delete();
    }

    await widget.snap.reference.update(upd);

    final afterName = _name.text.trim();
    final afterVariant = _variant.text.trim();
    final after = <String, dynamic>{
      'stock': _num(_stock.text),
      'sell_per_kg': _num(_sellPerKg.text),
      'cost_per_kg': _num(_costPerKg.text),
    };
    final changed =
        beforeName != afterName ||
        beforeVariant != afterVariant ||
        (_num(before['stock']) - _num(after['stock'])).abs() > 0.0001 ||
        (_num(before['sell_per_kg']) - _num(after['sell_per_kg'])).abs() >
            0.0001 ||
        (_num(before['cost_per_kg']) - _num(after['cost_per_kg'])).abs() >
            0.0001;
    if (changed) {
      try {
        await logInventoryChange(
          action: 'update',
          collection: widget.collection,
          itemId: widget.snap.id,
          name: afterName,
          variant: afterVariant,
          before: before,
          after: after,
          unit: 'g',
          source: 'manage_edit',
        );
      } catch (_) {
        // ignore log failures
      }
    }
    return true;
  }

  Future<bool> _saveDrink() async {
    final variants = _drinkVariants.map((e) => e.name).toList();
    final roasts = _drinkRoasts.map((e) => e.name).toList();
    final hasVariants = variants.isNotEmpty;
    final hasMatrix = variants.isNotEmpty || roasts.isNotEmpty;
    final pricing = <Map<String, dynamic>>[];

    if (hasMatrix) {
      _syncDrinkPricing();
      final variantIds = _drinkVariants.isEmpty
          ? <String>[_ProductEditSheetState._defaultVariantId]
          : _drinkVariants.map((e) => e.id).toList();
      final roastIds = _drinkRoasts.isEmpty
          ? <String>[_ProductEditSheetState._defaultRoastId]
          : _drinkRoasts.map((e) => e.id).toList();

      for (final vId in variantIds) {
        for (final rId in roastIds) {
          final row = _drinkPrices[_priceKey(vId, rId)];
          if (row == null) continue;
          final entry = <String, dynamic>{
            'sellPrice': _num(row.sellCtrl.text),
            'costPrice': _num(row.costCtrl.text),
          };
          final variant = _variantNameFor(vId);
          final roast = _roastNameFor(rId);
          if (variant.isNotEmpty) entry['variant'] = variant;
          if (roast.isNotEmpty) entry['roast'] = roast;
          if (_drinkSpicedEnabled) {
            entry['spicedPriceDelta'] = _num(row.spicedSellCtrl.text);
            entry['spicedCostDelta'] = _num(row.spicedCostCtrl.text);
          }
          pricing.add(entry);
        }
      }
    }

    double baseSell = _num(_sellPrice.text);
    double baseCost = _num(_costPrice.text);
    if (hasMatrix && pricing.isNotEmpty) {
      baseSell = _num(pricing.first['sellPrice']);
      baseCost = _num(pricing.first['costPrice']);
    }

    final upd = <String, dynamic>{
      'name': _name.text.trim(),
      'unit': _unit.text.trim().isEmpty ? 'cup' : _unit.text.trim(),
      'sellPrice': baseSell,
      'costPrice': baseCost,
      'variants': variants,
      'roastLevels': roasts,
      'spicedEnabled': _drinkSpicedEnabled,
    };
    _applyPosOrder(upd);
    final stockTxt = _stock.text.trim();
    if (stockTxt.isNotEmpty) {
      upd['stock'] = _num(_stock.text);
    }

    if (hasMatrix && pricing.isNotEmpty) {
      upd['pricing'] = pricing;
    } else {
      upd['pricing'] = FieldValue.delete();
    }

    if (!hasMatrix && _drinkSpicedEnabled) {
      upd['spicedPriceDelta'] = _num(_spicedPriceDelta.text);
      upd['spicedCostDelta'] = _num(_spicedCostDelta.text);
    } else {
      upd['spicedPriceDelta'] = FieldValue.delete();
      upd['spicedCostDelta'] = FieldValue.delete();
    }

    if (roasts.isNotEmpty) {
      _syncRoastUsage();
      final missingItem = _drinkRoasts.any(
        (roast) => _roastUsage[roast.id]?.item == null,
      );
      if (missingItem) {
        setState(() => _showRoastUsageErrors = true);
        return false;
      } else if (_showRoastUsageErrors) {
        setState(() => _showRoastUsageErrors = false);
      }

      final roastUsage = <Map<String, dynamic>>[];
      for (final roast in _drinkRoasts) {
        final usage = _roastUsage[roast.id]!;
        final item = usage.item!;
        final entry = <String, dynamic>{
          'roast': roast.name,
          'usedItem': {
            'id': item.id,
            'name': item.name,
            'variant': item.variant,
            'collection': usage.coll ?? item.coll,
          },
        };
        if (hasVariants) {
          final usedAmounts = <String, double>{};
          for (final variant in _drinkVariants) {
            usedAmounts[variant.name] = _num(usage.gramsFor(variant.id).text);
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
      upd['roastUsage'] = roastUsage;
      upd['usedItem'] = FieldValue.delete();
      upd['usedAmount'] = FieldValue.delete();
      upd['usedAmountByVariant'] = FieldValue.delete();
    } else {
      final usedItem = _drinkIngredient;
      if (usedItem != null) {
        upd['usedItem'] = {
          'id': usedItem.id,
          'name': usedItem.name,
          'variant': usedItem.variant,
          'collection': _drinkIngredientColl ?? usedItem.coll,
        };
      } else {
        upd['usedItem'] = FieldValue.delete();
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
          upd['usedAmountByVariant'] = usedByVariant;
          upd['usedAmount'] = usedByVariant.values.first;
        } else {
          upd['usedAmountByVariant'] = FieldValue.delete();
          upd['usedAmount'] = FieldValue.delete();
        }
      } else {
        final usedAmount = _num(_drinkUsedGrams.text);
        if (usedAmount > 0) {
          upd['usedAmount'] = usedAmount;
        } else {
          upd['usedAmount'] = FieldValue.delete();
        }
        upd['usedAmountByVariant'] = FieldValue.delete();
      }
      upd['roastUsage'] = FieldValue.delete();
    }

    if (_showLegacyDrinkFields) {
      upd['doublePrice'] = _num(_doublePrice.text);
      upd['doubleCost'] = _num(_doubleCost.text);
      upd['spicedCupCost'] = _num(_spicedCupCost.text);
      upd['spicedDoubleCupCost'] = _num(_spicedDoubleCupCost.text);
    }

    await widget.snap.reference.update(upd);
    return true;
  }
}
