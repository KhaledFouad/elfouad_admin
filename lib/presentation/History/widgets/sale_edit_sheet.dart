import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

import '../utils/sales_history_utils.dart';

class SaleEditSheet extends StatefulWidget {
  const SaleEditSheet({super.key, required this.snap});

  final DocumentSnapshot<Map<String, dynamic>> snap;

  @override
  State<SaleEditSheet> createState() => _SaleEditSheetState();
}

class _SaleEditSheetState extends State<SaleEditSheet> {
  late Map<String, dynamic> _m;
  late String _type;

  final TextEditingController _totalPriceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _gramsCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool _isComplimentary = false;
  bool _isSpiced = false;
  bool _busy = false;

  double _unitPriceCache = 0.0;
  double _unitCostCache = 0.0;
  bool _userEditedTotal = false;
  double? _lastNonComplPrice;

  double _numOf(dynamic v, [double def = 0.0]) =>
      (v is num) ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? def);
  int _intOf(dynamic v, [int def = 0]) =>
      (v is num) ? v.toInt() : (int.tryParse('${v ?? ''}') ?? def);

  @override
  void initState() {
    super.initState();
    _m = widget.snap.data() ?? {};
    _type = (_m['type'] ?? 'unknown').toString();

    _totalPriceCtrl.text = _numOf(_m['total_price']).toStringAsFixed(2);
    _noteCtrl.text = ((_m['note'] ?? _m['notes'] ?? '') as Object).toString();

    _isComplimentary = (_m['is_complimentary'] ?? false) == true;
    _isSpiced = (_m['is_spiced'] ?? false) == true;

    if (_type == 'drink') {
      final q = _numOf(_m['quantity'], 1);
      _qtyCtrl.text = (q == q.roundToDouble())
          ? q.toStringAsFixed(0)
          : q.toStringAsFixed(2);
    } else if (_type == 'single' || _type == 'ready_blend') {
      final g = _numOf(_m['grams']);
      if (g > 0) _gramsCtrl.text = g.toStringAsFixed(0);
    } else if (_type == 'extra') {
      final oldQty = _intOf(_m['quantity'], 1);
      _qtyCtrl.text = oldQty.toString();

      final unitPrice = _numOf(_m['unit_price']);
      final unitCost = _numOf(_m['unit_cost']);
      _unitPriceCache = unitPrice > 0
          ? unitPrice
          : (_numOf(_m['total_price']) / (oldQty > 0 ? oldQty : 1));
      _unitCostCache = unitCost > 0
          ? unitCost
          : (_numOf(_m['total_cost']) / (oldQty > 0 ? oldQty : 1));

      _totalPriceCtrl.addListener(() {
        _userEditedTotal = true;
      });

      _qtyCtrl.addListener(() {
        if (_isComplimentary) return;
        if (_userEditedTotal) return;
        final q = _intOf(_qtyCtrl.text, 1).clamp(1, 100000);
        final newTotal = _unitPriceCache * q;
        _setTotalPriceText(newTotal);
      });
    }
  }

  @override
  void dispose() {
    _totalPriceCtrl.dispose();
    _qtyCtrl.dispose();
    _gramsCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _setTotalPriceText(double v) {
    final s = v.toStringAsFixed(2);
    if (_totalPriceCtrl.text != s) {
      _totalPriceCtrl.text = s;
      _totalPriceCtrl.selection = TextSelection.collapsed(offset: s.length);
    }
  }

  Map<DocumentReference<Map<String, dynamic>>, double> _opsFromSale(
    Map<String, dynamic> m,
  ) {
    final db = FirebaseFirestore.instance;
    final out = <DocumentReference<Map<String, dynamic>>, double>{};

    double d(v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

    void acc(String? coll, dynamic id, double grams) {
      if (coll == null || id == null || grams <= 0) return;
      final ref = db.collection(coll).doc(id.toString());
      out[ref] = (out[ref] ?? 0) + grams;
    }

    final type = '${m['type'] ?? ''}';

    if (type == 'single' || type == 'ready_blend') {
      final coll = (type == 'single') ? 'singles' : 'blends';
      final id = m['single_id'] ?? m['blend_id'] ?? m['item_id'] ?? m['id'];
      final grams = d(m['grams']);
      acc(coll, id, grams);
      return out;
    }

    if (type == 'custom_blend') {
      List<Map<String, dynamic>> asList(dynamic v) {
        if (v is List) {
          return v
              .map(
                (e) => (e is Map)
                    ? e.cast<String, dynamic>()
                    : <String, dynamic>{},
              )
              .toList();
        }
        return const [];
      }

      final rows = [
        ...asList(m['components']),
        ...asList(m['items']),
        ...asList(m['lines']),
      ];

      for (final r in rows) {
        final grams = d(r['grams']);
        String? coll = (r['coll'] ?? r['collection'])?.toString();
        dynamic id = r['id'] ?? r['item_id'] ?? r['single_id'] ?? r['blend_id'];

        coll ??= (r['blend_id'] != null)
            ? 'blends'
            : (r['single_id'] != null)
                ? 'singles'
                : null;

        acc(coll, id, grams);
      }
      return out;
    }

    return out;
  }

  Future<void> _applyStockDeltaAndUpdate(Map<String, dynamic> updates) async {
    final saleRef = widget.snap.reference;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final oldSnap = await tx.get(saleRef);
      final oldSale = oldSnap.data() ?? <String, dynamic>{};

      final newSale = {...oldSale, ...updates};

      final oldOps = _opsFromSale(oldSale);
      final newOps = _opsFromSale(newSale);

      final refs = {...oldOps.keys, ...newOps.keys};
      for (final r in refs) {
        final oldG = oldOps[r] ?? 0.0;
        final newG = newOps[r] ?? 0.0;
        final diff = newG - oldG;
        if (diff.abs() > 0.0001) {
          tx.update(r, {'stock': FieldValue.increment(-diff)});
        }
      }

      tx.update(saleRef, updates);
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
      final pricePerG = pricePerKg > 0
          ? pricePerKg / 1000.0
          : _numOf(_m['price_per_g']);
      final costPerG = costPerKg > 0
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
          spicePricePerKg =
              (type == 'single') ? spiceRatePerKgForSingle(name) : 40.0;
        }
        if (spiceCostPerKg < 0) spiceCostPerKg = 0.0;

        double spiceAmount = 0.0;
        double spiceCostAmount = 0.0;

        if (_isComplimentary) {
          newTotalPrice = 0.0;
          newTotalCost = beansCost;
          updates['beans_amount'] = 0.0;
          updates['spice_rate_per_kg'] = 0.0;
          updates['spice_cost_per_kg'] = 0.0;
          updates['spice_amount'] = 0.0;
          updates['spice_cost_amount'] = 0.0;
          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          updates['profit_total'] = 0.0;
        } else if (manualOverride) {
          if (_isSpiced) {
            spiceAmount = (grams / 1000.0) * spicePricePerKg;
            spiceCostAmount = (grams / 1000.0) * spiceCostPerKg;
          }
          final beansAmountFromUi = (uiTotalPrice - spiceAmount).clamp(
            0.0,
            double.infinity,
          );
          newTotalPrice = uiTotalPrice;
          newTotalCost = beansCost + spiceCostAmount;

          updates['beans_amount'] = beansAmountFromUi;
          updates['spice_rate_per_kg'] = _isSpiced ? spicePricePerKg : 0.0;
          updates['spice_cost_per_kg'] = _isSpiced ? spiceCostPerKg : 0.0;
          updates['spice_amount'] = spiceAmount;
          updates['spice_cost_amount'] = spiceCostAmount;

          final autoPrice = beansAmount + (_isSpiced ? spiceAmount : 0.0);
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
          newTotalPrice = beansAmount + spiceAmount;
          newTotalCost = beansCost + spiceCostAmount;

          updates['beans_amount'] = beansAmount;
          updates['spice_rate_per_kg'] = _isSpiced ? spicePricePerKg : 0.0;
          updates['spice_cost_per_kg'] = _isSpiced ? spiceCostPerKg : 0.0;
          updates['spice_amount'] = spiceAmount;
          updates['spice_cost_amount'] = spiceCostAmount;

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
          final spiceRatePerKg =
              (rates.pricePerKg > 0) ? rates.pricePerKg : 50.0;
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

  @override
  Widget build(BuildContext context) {
    final name =
        (_m['name'] ?? _m['drink_name'] ?? AppStrings.saleOperationLabel)
            .toString();
    final createdAt = (_m['created_at'] as Timestamp?)?.toDate();
    final when = createdAt != null
        ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}  '
              '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    final isDrink = _type == 'drink';
    final isWeighted = _type == 'single' || _type == 'ready_blend';
    final isExtras = _type == 'extra';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 42,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                if (when.isNotEmpty)
                  Text(when, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalPriceCtrl,
                  enabled: !_isComplimentary,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: AppStrings.totalPriceLabel,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                if (isDrink) ...[
                  TextFormField(
                    controller: _qtyCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: AppStrings.cupsCountLabel,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (isWeighted) ...[
                  TextFormField(
                    controller: _gramsCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: AppStrings.gramsQuantityLabel,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (isExtras) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: AppStrings.quantityLabel,
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          IconButton(
                            tooltip: AppStrings.increaseLabel,
                            onPressed: () {
                              final q = _intOf(_qtyCtrl.text, 1) + 1;
                              _qtyCtrl.text = q.toString();
                              if (!_isComplimentary && !_userEditedTotal) {
                                _setTotalPriceText(_unitPriceCache * q);
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          IconButton(
                            tooltip: AppStrings.decreaseLabel,
                            onPressed: () {
                              var q = _intOf(_qtyCtrl.text, 1);
                              q = (q > 1) ? q - 1 : 1;
                              _qtyCtrl.text = q.toString();
                              if (!_isComplimentary && !_userEditedTotal) {
                                _setTotalPriceText(_unitPriceCache * q);
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: _noteCtrl,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: AppStrings.noteOptionalLabel,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _isComplimentary,
                  onChanged: (v) {
                    setState(() {
                      final nv = v ?? false;
                      _isComplimentary = nv;
                      if (isExtras) {
                        if (nv) {
                          _lastNonComplPrice = double.tryParse(
                            _totalPriceCtrl.text.replaceAll(',', '.'),
                          );
                          _setTotalPriceText(0.0);
                        } else {
                          final q = _intOf(_qtyCtrl.text, 1).clamp(1, 100000);
                          final back =
                              _userEditedTotal && _lastNonComplPrice != null
                                  ? _lastNonComplPrice!
                                  : (_unitPriceCache * q);
                          _setTotalPriceText(back);
                        }
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(AppStrings.complimentaryLabel),
                ),
                if ((_type == 'single' || _type == 'ready_blend') ||
                    (_m.containsKey('is_spiced') && !isExtras))
                  CheckboxListTile(
                    value: _isSpiced,
                    onChanged: (v) => setState(() => _isSpiced = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(AppStrings.spicedLabel),
                  ),
                const SizedBox(height: 8),
                const Text(
                  AppStrings.deferredProfitNote,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text(AppStrings.actionCancel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text(AppStrings.actionSave),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
