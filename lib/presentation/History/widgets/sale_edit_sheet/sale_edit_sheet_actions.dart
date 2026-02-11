// ignore_for_file: invalid_use_of_protected_member
part of '../sale_edit_sheet.dart';

/// Save/delete actions and update mutation builders.
extension _SaleEditSheetActions on _SaleEditSheetState {
  Future<void> _applyStockDeltaAndUpdate(
    Map<String, dynamic> updates, {
    DocumentReference<Map<String, dynamic>>? targetRef,
  }) async {
    final saleRef = widget.snap.reference;
    final resolvedTarget = targetRef ?? saleRef;
    final moving = resolvedTarget.path != saleRef.path;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final oldSnap = await tx.get(saleRef);
      final oldSale = oldSnap.data() ?? <String, dynamic>{};

      final newSale = {...oldSale, ...updates};

      final drinkCache = <String, Map<String, dynamic>>{};

      Future<Map<DocumentReference<Map<String, dynamic>>, double>> opsForSale(
        Map<String, dynamic> sale,
      ) async {
        final base = _opsFromSale(sale);
        if (base.isNotEmpty || !_isDrinkSale(sale)) return base;

        final drinkId = _drinkIdFromSale(sale);
        if (drinkId == null || drinkId.isEmpty) return base;

        final cached = drinkCache[drinkId];
        if (cached != null) {
          return _opsFromSale(sale, usageSource: cached);
        }

        final drinkRef = saleRef.firestore.collection('drinks').doc(drinkId);
        final drinkSnap = await tx.get(drinkRef);
        final drinkData = drinkSnap.data();
        if (drinkData == null) return base;
        drinkCache[drinkId] = drinkData;
        return _opsFromSale(sale, usageSource: drinkData);
      }

      final oldOps = await opsForSale(oldSale);
      final newOps = await opsForSale(newSale);

      final refs = {...oldOps.keys, ...newOps.keys};
      for (final r in refs) {
        final oldG = oldOps[r] ?? 0.0;
        final newG = newOps[r] ?? 0.0;
        final diff = newG - oldG;
        if (diff.abs() > 0.0001) {
          tx.update(r, {'stock': FieldValue.increment(-diff)});
        }
      }

      if (moving) {
        tx.set(resolvedTarget, newSale);
        tx.delete(saleRef);
      } else {
        tx.update(saleRef, updates);
      }
    });
  }

  Future<void> _applyExtrasDeltaAndUpdate(
    Map<String, dynamic> updates,
    int newQty,
  ) async {
    final saleRef = widget.snap.reference;
    final db = FirebaseFirestore.instance;

    await db.runTransaction((tx) async {
      final oldSnap = await tx.get(saleRef);
      final oldSale = oldSnap.data() ?? <String, dynamic>{};

      final oldQty = _intOf(oldSale['quantity'], 0);
      final delta = newQty - oldQty;

      final extraId = (oldSale['extra_id'] ?? '').toString();
      if (extraId.isNotEmpty) {
        final extraRef = db.collection('extras').doc(extraId);
        final exSnap = await tx.get(extraRef);
        if (!exSnap.exists) {
          throw Exception(AppStrings.extraNotFound);
        }
        final ex = exSnap.data() as Map<String, dynamic>;
        final cur = _intOf(ex['stock_units'], 0);

        if (delta > 0 && cur < delta) {
          throw Exception(AppStrings.insufficientStockPieces(cur));
        }

        tx.update(extraRef, {
          'stock_units': cur - delta,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      tx.update(saleRef, updates);
    });
  }

  void _removeInvoiceItem(int index) {
    if (_busy || index < 0 || index >= _invoiceItems.length) return;
    setState(() {
      final removed = _invoiceItems.removeAt(index);
      removed.dispose();
      _syncInvoiceTotals();
    });
  }

  Map<String, dynamic> _buildUpdatedInvoiceItem(
    _InvoiceItemDraft item, {
    required bool applyComplimentary,
  }) {
    final updated = Map<String, dynamic>.from(item.raw);
    final grams = _numOf(item.gramsCtrl.text);
    final qty = _numOf(item.qtyCtrl.text);
    final linePrice = _invoiceLinePrice(
      item,
      applyComplimentary: applyComplimentary,
    );
    final lineCost = _invoiceLineCost(item);

    final hasGramsKey =
        item.showGrams ||
        updated.containsKey('grams') ||
        updated.containsKey('weight');
    if (hasGramsKey) {
      updated['grams'] = grams;
      if (updated.containsKey('weight')) updated['weight'] = grams;
    }

    final hasQtyKey =
        item.showQty ||
        updated.containsKey('qty') ||
        updated.containsKey('quantity') ||
        updated.containsKey('count') ||
        updated.containsKey('pieces');
    if (hasQtyKey) {
      if (updated.containsKey('qty') || !updated.containsKey('quantity')) {
        updated['qty'] = qty;
      }
      if (updated.containsKey('quantity')) updated['quantity'] = qty;
      if (updated.containsKey('count')) updated['count'] = qty;
      if (updated.containsKey('pieces')) updated['pieces'] = qty;
    }

    if (item.unit.isNotEmpty) {
      updated['unit'] = item.unit;
    }

    updated['line_total_price'] = linePrice;
    updated['line_total_cost'] = lineCost;
    if (updated.containsKey('total_price')) updated['total_price'] = linePrice;
    if (updated.containsKey('total_cost')) updated['total_cost'] = lineCost;

    if (item.usesMeasure) {
      final measure = item.useGrams ? grams : qty;
      updated['unit_price'] = measure > 0 ? (linePrice / measure) : linePrice;
      if (item.unitCost > 0) {
        updated['unit_cost'] = item.unitCost;
      }
    }

    final metaRaw = updated['meta'];
    Map<String, dynamic>? metaMap = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : null;

    if (item.spicedEnabled) {
      metaMap ??= <String, dynamic>{};
      metaMap['spicedEnabled'] = true;
      metaMap['spiced'] = item.spiced;
      updated['spiced'] = item.spiced;
      if (updated.containsKey('is_spiced')) {
        updated['is_spiced'] = item.spiced;
      }
    }

    final ginsengValue = _intOf(item.ginsengCtrl.text, 0).clamp(0, 100000);
    final hasGinsengKey =
        item.showGinseng ||
        updated.containsKey('ginseng_grams') ||
        updated.containsKey('ginsengGrams') ||
        (metaMap?.containsKey('ginseng_grams') ?? false) ||
        (metaMap?.containsKey('ginsengGrams') ?? false);
    if (hasGinsengKey) {
      metaMap ??= <String, dynamic>{};
      if (ginsengValue > 0) {
        metaMap['ginseng_grams'] = ginsengValue;
      } else {
        metaMap.remove('ginseng_grams');
        metaMap.remove('ginsengGrams');
      }
      if (updated.containsKey('ginseng_grams')) {
        updated['ginseng_grams'] = ginsengValue;
      } else if (ginsengValue > 0) {
        updated['ginseng_grams'] = ginsengValue;
      }
      if (updated.containsKey('ginsengGrams')) {
        updated['ginsengGrams'] = ginsengValue;
      }
    }

    if (metaMap != null) {
      updated['meta'] = metaMap;
    }

    return updated;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final updates = <String, dynamic>{};
      final type = _type;

      final oldTotalPrice = _numOf(_m['total_price']);
      final oldTotalCost = _numOf(_m['total_cost']);

      final bool isDeferred = (_m['is_deferred'] ?? false) == true;
      final bool paid = (_m['paid'] ?? (!isDeferred)) == true;
      bool freezeProfit = isDeferred && !paid;

      updates['note'] = _noteCtrl.text.trim();
      updates['is_complimentary'] = _isComplimentary;
      updates['is_spiced'] = _isSpiced;

      if (_isComplimentary) freezeProfit = false;

      if (type == 'invoice') {
        final bool isDeferred = _isDeferred;
        final bool isComplimentaryInvoice = _isComplimentary && !isDeferred;
        final bool paid = _isPaid;
        bool freezeProfitInvoice = isDeferred && !paid;
        if (isComplimentaryInvoice) freezeProfitInvoice = false;
        updates['is_complimentary'] = isComplimentaryInvoice;

        final updatedItems = <Map<String, dynamic>>[];
        double totalPrice = 0.0;
        double totalCost = 0.0;

        for (final item in _invoiceItems) {
          final linePrice = _invoiceLinePrice(
            item,
            applyComplimentary: isComplimentaryInvoice,
          );
          final lineCost = _invoiceLineCost(item);
          totalPrice += linePrice;
          totalCost += lineCost;
          updatedItems.add(
            _buildUpdatedInvoiceItem(
              item,
              applyComplimentary: isComplimentaryInvoice,
            ),
          );
        }

        if (isComplimentaryInvoice) {
          totalPrice = 0.0;
        }

        updates['items'] = updatedItems;
        updates['total_price'] = totalPrice;
        updates['total_cost'] = totalCost;
        if (isComplimentaryInvoice) {
          updates['profit_total'] = 0.0;
        } else if (!freezeProfitInvoice) {
          updates['profit_total'] = totalPrice - totalCost;
        }

        updates['is_deferred'] = isDeferred;
        updates['paid'] = paid;
        final dueInput = _numOf(_dueAmountCtrl.text);
        updates['due_amount'] = _normalizeDueAmount(
          input: dueInput,
          totalPrice: totalPrice,
          isDeferred: isDeferred,
          isPaid: paid,
        );

        updates['manual_override'] = true;
        updates['updated_at'] = FieldValue.serverTimestamp();

        final currentRef = widget.snap.reference;
        final isDeferredCollection = currentRef.parent.id == 'deferred_sales';
        DocumentReference<Map<String, dynamic>>? targetRef;
        if (isDeferred && !isDeferredCollection) {
          targetRef = currentRef.firestore
              .collection('deferred_sales')
              .doc(currentRef.id);
        } else if (!isDeferred && isDeferredCollection) {
          targetRef = currentRef.firestore
              .collection('sales')
              .doc(currentRef.id);
        }

        await _applyStockDeltaAndUpdate(updates, targetRef: targetRef);
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.editSaved)));
        return;
      }

      if (type == 'extra') {
        final int newQty = _intOf(
          _qtyCtrl.text.isEmpty ? null : _qtyCtrl.text,
          1,
        ).clamp(1, 100000);
        final double uiTotal =
            double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ??
            oldTotalPrice;

        final bool manualOverride = !_isComplimentary && _userEditedTotal;

        double newTotalPrice, newTotalCost, newUnitPrice, newUnitCost;

        newUnitPrice = _unitPriceCache;
        newUnitCost = _unitCostCache;

        if (_isComplimentary) {
          newTotalPrice = 0.0;
          newTotalCost = newUnitCost * newQty;
          updates['unit_price'] = 0.0;
          updates['unit_cost'] = newUnitCost;
          updates['profit_total'] = 0.0;
        } else if (manualOverride) {
          newTotalPrice = uiTotal;
          newTotalCost = newUnitCost * newQty;
          newUnitPrice = (newQty > 0)
              ? (newTotalPrice / newQty)
              : newTotalPrice;
          updates['unit_price'] = newUnitPrice;
          updates['unit_cost'] = newUnitCost;
          updates['manual_override'] = true;
          updates['discount_amount'] =
              (_unitPriceCache * newQty) - newTotalPrice;
          if (!freezeProfit) {
            updates['profit_total'] = newTotalPrice - newTotalCost;
          }
        } else {
          newTotalPrice = _unitPriceCache * newQty;
          newTotalCost = newUnitCost * newQty;
          updates['unit_price'] = _unitPriceCache;
          updates['unit_cost'] = newUnitCost;
          if (!freezeProfit) {
            updates['profit_total'] = newTotalPrice - newTotalCost;
          }
        }

        updates['quantity'] = newQty;
        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        updates['updated_at'] = FieldValue.serverTimestamp();

        await _applyExtrasDeltaAndUpdate(updates, newQty);

        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.editSaved)));
        return;
      }

      final listPrice = _numOf(_m['list_price']);
      final unitPrice = _numOf(_m['unit_price']);
      final unitCost = _numOf(_m['unit_cost']) > 0
          ? _numOf(_m['unit_cost'])
          : _numOf(_m['list_cost']);

      final pricePerKg = _numOf(_m['price_per_kg']);
      final costPerKg = _numOf(_m['cost_per_kg']);
      double pricePerG = pricePerKg > 0
          ? pricePerKg / 1000.0
          : _numOf(_m['price_per_g']);
      double costPerG = costPerKg > 0
          ? costPerKg / 1000.0
          : _numOf(_m['cost_per_g']);

      final uiTotalPrice =
          double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ??
          oldTotalPrice;
      double qty =
          double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ??
          _numOf(_m['quantity']);
      double grams =
          double.tryParse(_gramsCtrl.text.replaceAll(',', '.')) ??
          _numOf(_m['grams']);
      final baseGrams = _numOf(_m['grams']);
      final gramsForRate = baseGrams > 0 ? baseGrams : grams;
      final baseBeansAmount = _numOf(_m['beans_amount']);
      final baseSpiceAmount = _numOf(_m['spice_amount']);
      final baseSpiceCostAmount = _numOf(_m['spice_cost_amount']);
      final baseBeansCost = (oldTotalCost - baseSpiceCostAmount).clamp(
        0.0,
        double.infinity,
      );
      if (pricePerG <= 0 && gramsForRate > 0) {
        if (baseBeansAmount > 0) {
          pricePerG = baseBeansAmount / gramsForRate;
        } else {
          pricePerG = (oldTotalPrice - baseSpiceAmount) / gramsForRate;
        }
      }
      if (costPerG <= 0 && gramsForRate > 0) {
        if (baseBeansCost > 0) {
          costPerG = baseBeansCost / gramsForRate;
        } else {
          costPerG = oldTotalCost / gramsForRate;
        }
      }

      double newTotalPrice = oldTotalPrice;
      double newTotalCost = oldTotalCost;

      final bool manualOverride =
          !_isComplimentary && (uiTotalPrice - oldTotalPrice).abs() > 0.0005;

      if (type == 'drink') {
        qty = qty <= 0 ? 1 : qty;
        updates['quantity'] = qty;

        if (_isComplimentary) {
          newTotalPrice = 0.0;
          newTotalCost = unitCost * qty;
          updates['unit_price'] = 0.0;
          updates['unit_cost'] = unitCost;
          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          updates['profit_total'] = 0.0;
        } else if (manualOverride) {
          final u = (qty > 0) ? (uiTotalPrice / qty) : uiTotalPrice;
          updates['unit_price'] = u;
          updates['unit_cost'] = unitCost;
          newTotalPrice = uiTotalPrice;
          newTotalCost = unitCost * qty;
          updates['manual_override'] = true;
          updates['discount_amount'] = (listPrice * qty) - newTotalPrice;
          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit) {
            updates['profit_total'] = newTotalPrice - newTotalCost;
          }
        } else {
          final unitPriceEffective = unitPrice > 0 ? unitPrice : listPrice;
          updates['unit_price'] = unitPriceEffective;
          updates['unit_cost'] = unitCost;
          newTotalPrice = unitPriceEffective * qty;
          newTotalCost = unitCost * qty;
          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit) {
            updates['profit_total'] = newTotalPrice - newTotalCost;
          }
        }

        await _applyStockDeltaAndUpdate(updates);
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.editSaved)));
        return;
      }

      if (type == 'single' || type == 'ready_blend') {
        grams = grams > 0 ? grams : _numOf(_m['grams']);
        updates['grams'] = grams;
        final int ginsengGrams = _intOf(
          _ginsengCtrl.text.isEmpty ? null : _ginsengCtrl.text,
          0,
        ).clamp(0, 100000).toInt();
        updates['ginseng_grams'] = ginsengGrams;
        final rawMeta = _m['meta'];
        final metaMap = rawMeta is Map
            ? Map<String, dynamic>.from(rawMeta)
            : null;
        if (metaMap != null || ginsengGrams > 0) {
          final updatedMeta = metaMap ?? <String, dynamic>{};
          if (ginsengGrams > 0) {
            updatedMeta['ginseng_grams'] = ginsengGrams;
          } else {
            updatedMeta.remove('ginseng_grams');
          }
          updates['meta'] = updatedMeta;
        }

        final beansAmount = pricePerG * grams;
        final beansCost = costPerG * grams;

        final saleForRates = {..._m, 'type': type};
        final rates = await fetchSpiceRatesForSale(saleForRates);
        double spicePricePerKg = rates.pricePerKg;
        double spiceCostPerKg = rates.costPerKg;

        if (spicePricePerKg <= 0) {
          final name =
              (_m['name'] ?? _m['single_name'] ?? _m['blend_name'] ?? '')
                  .toString();
          spicePricePerKg = (type == 'single')
              ? spiceRatePerKgForSingle(name)
              : 40.0;
        }
        if (spiceCostPerKg < 0) spiceCostPerKg = 0.0;

        double ginsengPricePerKg = 0.0;
        double ginsengCostPerKg = 0.0;
        if (ginsengGrams > 0) {
          final ginsengRates = await fetchGinsengRatesForSale(saleForRates);
          ginsengPricePerKg = ginsengRates.pricePerKg;
          ginsengCostPerKg = ginsengRates.costPerKg;
          if (ginsengCostPerKg < 0) ginsengCostPerKg = 0.0;
        }

        double spiceAmount = 0.0;
        double spiceCostAmount = 0.0;
        double ginsengAmount = 0.0;
        double ginsengCostAmount = 0.0;

        if (_isComplimentary) {
          newTotalPrice = 0.0;
          newTotalCost = beansCost;
          updates['beans_amount'] = 0.0;
          updates['spice_rate_per_kg'] = 0.0;
          updates['spice_cost_per_kg'] = 0.0;
          updates['spice_amount'] = 0.0;
          updates['spice_cost_amount'] = 0.0;
          updates['ginseng_rate_per_kg'] = 0.0;
          updates['ginseng_cost_per_kg'] = 0.0;
          updates['ginseng_amount'] = 0.0;
          updates['ginseng_cost_amount'] = 0.0;
          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          updates['profit_total'] = 0.0;
        } else if (manualOverride) {
          if (_isSpiced) {
            spiceAmount = (grams / 1000.0) * spicePricePerKg;
            spiceCostAmount = (grams / 1000.0) * spiceCostPerKg;
          }
          if (ginsengGrams > 0) {
            ginsengAmount = (ginsengGrams / 1000.0) * ginsengPricePerKg;
            ginsengCostAmount = (ginsengGrams / 1000.0) * ginsengCostPerKg;
          }
          final beansAmountFromUi = (uiTotalPrice - spiceAmount - ginsengAmount)
              .clamp(0.0, double.infinity);
          newTotalPrice = uiTotalPrice;
          newTotalCost = beansCost + spiceCostAmount + ginsengCostAmount;

          updates['beans_amount'] = beansAmountFromUi;
          updates['spice_rate_per_kg'] = _isSpiced ? spicePricePerKg : 0.0;
          updates['spice_cost_per_kg'] = _isSpiced ? spiceCostPerKg : 0.0;
          updates['spice_amount'] = spiceAmount;
          updates['spice_cost_amount'] = spiceCostAmount;
          updates['ginseng_rate_per_kg'] = ginsengGrams > 0
              ? ginsengPricePerKg
              : 0.0;
          updates['ginseng_cost_per_kg'] = ginsengGrams > 0
              ? ginsengCostPerKg
              : 0.0;
          updates['ginseng_amount'] = ginsengAmount;
          updates['ginseng_cost_amount'] = ginsengCostAmount;

          final autoPrice =
              beansAmount + (_isSpiced ? spiceAmount : 0.0) + ginsengAmount;
          updates['manual_override'] = true;
          updates['discount_amount'] = (autoPrice - newTotalPrice);

          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit) {
            updates['profit_total'] = newTotalPrice - newTotalCost;
          }
        } else {
          if (_isSpiced) {
            spiceAmount = (grams / 1000.0) * spicePricePerKg;
            spiceCostAmount = (grams / 1000.0) * spiceCostPerKg;
          }
          if (ginsengGrams > 0) {
            ginsengAmount = (ginsengGrams / 1000.0) * ginsengPricePerKg;
            ginsengCostAmount = (ginsengGrams / 1000.0) * ginsengCostPerKg;
          }
          newTotalPrice = beansAmount + spiceAmount + ginsengAmount;
          newTotalCost = beansCost + spiceCostAmount + ginsengCostAmount;

          updates['beans_amount'] = beansAmount;
          updates['spice_rate_per_kg'] = _isSpiced ? spicePricePerKg : 0.0;
          updates['spice_cost_per_kg'] = _isSpiced ? spiceCostPerKg : 0.0;
          updates['spice_amount'] = spiceAmount;
          updates['spice_cost_amount'] = spiceCostAmount;
          updates['ginseng_rate_per_kg'] = ginsengGrams > 0
              ? ginsengPricePerKg
              : 0.0;
          updates['ginseng_cost_per_kg'] = ginsengGrams > 0
              ? ginsengCostPerKg
              : 0.0;
          updates['ginseng_amount'] = ginsengAmount;
          updates['ginseng_cost_amount'] = ginsengCostAmount;

          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit) {
            updates['profit_total'] = newTotalPrice - newTotalCost;
          }
        }

        updates['price_per_kg'] = pricePerKg;
        updates['price_per_g'] = pricePerG;
        updates['cost_per_kg'] = costPerKg;
        updates['cost_per_g'] = costPerG;

        await _applyStockDeltaAndUpdate(updates);
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.editSaved)));
        return;
      }

      if (type == 'custom_blend') {
        final linesAmount = _numOf(_m['lines_amount']);
        final gramsAll = (_numOf(_m['total_grams']) > 0)
            ? _numOf(_m['total_grams'])
            : _numOf(_m['total_grams']);

        double spiceAmount = 0.0;
        if (_isSpiced && !_isComplimentary) {
          final rates = await fetchSpiceRatesForSale({..._m, 'type': type});
          final spiceRatePerKg = (rates.pricePerKg > 0)
              ? rates.pricePerKg
              : 50.0;
          spiceAmount = (gramsAll / 1000.0) * spiceRatePerKg;
          updates['spice_rate_per_kg'] = spiceRatePerKg;
          updates['spice_amount'] = spiceAmount;
        } else {
          updates['spice_rate_per_kg'] = 0.0;
          updates['spice_amount'] = 0.0;
        }

        final uiTotalPrice =
            double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ??
            oldTotalPrice;

        final autoPrice = linesAmount + spiceAmount;
        double newTotalPrice;
        if (_isComplimentary) {
          newTotalPrice = 0.0;
          updates['profit_total'] = 0.0;
        } else if (!_isComplimentary &&
            (uiTotalPrice - oldTotalPrice).abs() > 0.0005) {
          newTotalPrice = uiTotalPrice;
          updates['manual_override'] = true;
          updates['discount_amount'] = (autoPrice - newTotalPrice);
        } else {
          newTotalPrice = autoPrice;
        }

        final newTotalCost = _numOf(_m['total_cost']);

        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        if (!_isComplimentary && !freezeProfit) {
          updates['profit_total'] = newTotalPrice - newTotalCost;
        }

        await _applyStockDeltaAndUpdate(updates);
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.editSaved)));
        return;
      }

      {
        final uiTotalPrice =
            double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ??
            oldTotalPrice;

        double newTotalPrice, newTotalCost;
        if (_isComplimentary) {
          newTotalPrice = 0.0;
          newTotalCost = oldTotalCost;
          updates['profit_total'] = 0.0;
        } else {
          newTotalPrice = uiTotalPrice;
          newTotalCost = oldTotalCost;
          updates['manual_override'] = true;
          if (!freezeProfit) {
            updates['profit_total'] = newTotalPrice - newTotalCost;
          }
        }
        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;

        await _applyStockDeltaAndUpdate(updates);
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.editSaved)));
      }
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
