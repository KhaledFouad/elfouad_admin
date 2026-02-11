part of '../product_edit_sheet.dart';

/// Field initialization helpers derived from the loaded product data.
extension _ProductEditSheetInitHelpers on _ProductEditSheetState {
  void _initBeanFields() {
    _sellPerKg.text = _format(_num(_data['sellPricePerKg']));
    _costPerKg.text = _format(_num(_data['costPricePerKg']));
    final spicePrice = _num(_data['spicePricePerKg'] ?? _data['spicesPrice']);
    final spiceCost = _num(_data['spiceCostPerKg'] ?? _data['spicesCost']);
    _beanSpicedEnabled =
        (_data['spicedEnabled'] ?? false) == true ||
        spicePrice > 0 ||
        spiceCost > 0;
    _spicePricePerKg.text = _format(spicePrice);
    _spiceCostPerKg.text = _format(spiceCost);

    final extraIds = _extractExtraOptionIds(_data);
    _beanSelectedExtraIds
      ..clear()
      ..addAll(extraIds);
    _beanExtrasEnabled =
        (_data['extrasEnabled'] ?? false) == true || extraIds.isNotEmpty;
  }

  void _initDrinkFields() {
    _sellPrice.text = _format(_num(_data['sellPrice']));
    _costPrice.text = _format(_num(_data['costPrice']));
    _drinkSpicedEnabled = (_data['spicedEnabled'] ?? false) == true;
    _spicedPriceDelta.text = _format(_num(_data['spicedPriceDelta']));
    _spicedCostDelta.text = _format(_num(_data['spicedCostDelta']));

    _doublePrice.text = _format(_num(_data['doublePrice']));
    _doubleCost.text = _format(_num(_data['doubleCost']));
    _spicedCupCost.text = _format(_num(_data['spicedCupCost']));
    _spicedDoubleCupCost.text = _format(_num(_data['spicedDoubleCupCost']));
    _showLegacyDrinkFields =
        _data.containsKey('doublePrice') ||
        _data.containsKey('doubleCost') ||
        _data.containsKey('spicedCupCost') ||
        _data.containsKey('spicedDoubleCupCost');

    for (final v in _stringList(_data['variants'])) {
      _drinkVariants.add(_OptionEntry(_nextOptionId(), initial: v));
    }
    for (final r in _stringList(_data['roastLevels'])) {
      _drinkRoasts.add(_OptionEntry(_nextOptionId(), initial: r));
    }

    _syncDrinkPricing();
    _applyDrinkPricing(_mapList(_data['pricing']));

    _syncRoastUsage();
    _applyRoastUsage(_mapList(_data['roastUsage']));

    final usedItem = _mapOrNull(_data['usedItem']);
    if (usedItem != null) {
      _drinkIngredient = _inventoryFromMap(usedItem);
      _drinkIngredientColl = usedItem['collection']?.toString();
    }
    final usedByVariant = _mapOrNull(_data['usedAmountByVariant']);
    if (usedByVariant != null && usedByVariant.isNotEmpty) {
      if (_drinkVariants.isNotEmpty) {
        _applyVariantUsage(usedByVariant);
      } else {
        _drinkUsedGrams.text = _format(_num(usedByVariant.values.first));
      }
    } else {
      final usedAmount = _num(_data['usedAmount']);
      if (usedAmount > 0) {
        if (_drinkVariants.isNotEmpty) {
          for (final variant in _drinkVariants) {
            _variantGrams[variant.id]?.text = _format(usedAmount);
          }
        } else {
          _drinkUsedGrams.text = _format(usedAmount);
        }
      }
    }
  }
}
