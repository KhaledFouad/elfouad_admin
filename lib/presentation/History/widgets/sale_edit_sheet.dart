import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

import '../utils/sale_utils.dart';
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
  final TextEditingController _ginsengCtrl = TextEditingController();
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

  bool _isDrinkSale(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    if (type == 'drink') return true;
    return data.containsKey('drink_id') ||
        data.containsKey('drinkId') ||
        data.containsKey('drink_name') ||
        data.containsKey('drinkName');
  }

  String? _drinkIdFromSale(Map<String, dynamic> data) {
    final raw = data['drink_id'] ?? data['drinkId'] ?? data['drinkID'];
    final id = raw?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  String? _normalizeColl(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'single' || value == 'singles' || value == 'bean') {
      return 'singles';
    }
    if (value == 'beans') return 'singles';
    if (value == 'blend' || value == 'blends') return 'blends';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _m = widget.snap.data() ?? {};
    final rawType = (_m['type'] ?? '').toString();
    final linesType = (_m['lines_type'] ?? '').toString();
    _type = rawType.isNotEmpty
        ? rawType
        : (linesType.isNotEmpty ? linesType : detectSaleType(_m)).toString();

    _totalPriceCtrl.text = _numOf(_m['total_price']).toStringAsFixed(2);
    _noteCtrl.text = ((_m['note'] ?? _m['notes'] ?? '') as Object).toString();

    _isComplimentary = (_m['is_complimentary'] ?? false) == true;
    _isSpiced = (_m['is_spiced'] ?? false) == true;
    final meta = _m['meta'];
    final ginsengMeta = meta is Map
        ? (meta['ginseng_grams'] ?? meta['ginsengGrams'])
        : null;
    final ginsengGrams = _intOf(
      _m['ginseng_grams'] ?? _m['ginsengGrams'] ?? ginsengMeta,
      0,
    );
    if (ginsengGrams > 0) {
      _ginsengCtrl.text = ginsengGrams.toString();
    }

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
    _ginsengCtrl.dispose();
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
    Map<String, dynamic> m, {
    Map<String, dynamic>? usageSource,
  }) {
    final db = FirebaseFirestore.instance;
    final out = <DocumentReference<Map<String, dynamic>>, double>{};

    double d(v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

    void acc(String? coll, dynamic id, double grams) {
      final normalized = _normalizeColl(coll);
      if (normalized == null || id == null || grams <= 0) return;
      final ref = db.collection(normalized).doc(id.toString());
      out[ref] = (out[ref] ?? 0) + grams;
    }

    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map) {
        return v.cast<String, dynamic>();
      }
      return null;
    }

    List<Map<String, dynamic>> asList(dynamic v) {
      if (v is List) {
        return v
            .map(
              (e) =>
                  (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
            )
            .toList();
      }
      return const [];
    }

    List<Map<String, dynamic>> lineItems(Map<String, dynamic> data) {
      return [
        ...asList(data['components']),
        ...asList(data['items']),
        ...asList(data['lines']),
        ...asList(data['cart_items']),
        ...asList(data['order_items']),
        ...asList(data['products']),
      ];
    }

    String? collFromRow(Map<String, dynamic> row) {
      final raw =
          row['coll'] ?? row['collection'] ?? row['coll_name'] ?? row['coll'];
      final normalized = _normalizeColl(raw?.toString());
      if (normalized != null) return normalized;

      if (row['blend_id'] != null || row['blendId'] != null) return 'blends';
      if (row['single_id'] != null || row['singleId'] != null) {
        return 'singles';
      }

      final type = (row['type'] ?? row['line_type'] ?? row['item_type'] ?? '')
          .toString();
      if (type == 'single') return 'singles';
      if (type == 'ready_blend' || type == 'blend') return 'blends';

      return null;
    }

    dynamic idFromRow(Map<String, dynamic> row) {
      return row['id'] ??
          row['item_id'] ??
          row['itemId'] ??
          row['single_id'] ??
          row['singleId'] ??
          row['blend_id'] ??
          row['blendId'];
    }

    double gramsFromRow(Map<String, dynamic> row) {
      return d(
        row['grams'] ??
            row['weight'] ??
            row['grams_used'] ??
            row['used_grams'] ??
            row['usedGrams'],
      );
    }

    final rawType = (m['type'] ?? '').toString();
    final linesType = (m['lines_type'] ?? '').toString();
    final type = rawType.isNotEmpty
        ? rawType
        : (linesType.isNotEmpty ? linesType : detectSaleType(m)).toString();
    if (type == 'single' || type == 'ready_blend') {
      final coll = (type == 'single') ? 'singles' : 'blends';
      final id = m['single_id'] ?? m['blend_id'] ?? m['item_id'] ?? m['id'];
      final grams = d(m['grams']);
      acc(coll, id, grams);
    }

    if (out.isEmpty) {
      final rows = lineItems(m);
      for (final row in rows) {
        final grams = gramsFromRow(row);
        if (grams <= 0) continue;
        final coll = collFromRow(row);
        final id = idFromRow(row);
        acc(coll, id, grams);
      }
    }

    if (out.isEmpty && _isDrinkSale(m)) {
      final qtyRaw = m['quantity'] ?? m['qty'] ?? m['count'] ?? m['pieces'];
      var qty = d(qtyRaw);
      if (qty <= 0) qty = 1;

      final variant = (m['variant'] ?? m['drink_variant'] ?? m['size'] ?? '')
          .toString()
          .trim();
      final roast = (m['roast'] ?? m['roast_level'] ?? m['roastLevel'] ?? '')
          .toString()
          .trim();
      final variantKey = variant.toLowerCase();
      final roastKey = roast.toLowerCase();

      double amountFromVariant(Map<String, dynamic> byVariant) {
        if (variantKey.isEmpty) return 0.0;
        if (byVariant.containsKey(variant)) {
          return d(byVariant[variant]);
        }
        for (final entry in byVariant.entries) {
          if (entry.key.toString().trim().toLowerCase() == variantKey) {
            return d(entry.value);
          }
        }
        return 0.0;
      }

      Map<String, dynamic>? pickUsage(Map<String, dynamic> source) {
        final roastUsage = asList(
          source['roastUsage'] ?? source['roast_usage'],
        );
        if (roastUsage.isNotEmpty) {
          if (roastKey.isNotEmpty) {
            for (final entry in roastUsage) {
              final key = (entry['roast'] ?? entry['name'])
                  ?.toString()
                  .toLowerCase();
              if (key != null && key.trim() == roastKey) return entry;
            }
          }
          return roastUsage.first;
        }
        final usedItem = asMap(
          source['usedItem'] ??
              source['used_item'] ??
              source['ingredient'] ??
              source['item'],
        );
        return usedItem != null ? source : null;
      }

      void applyUsage(Map<String, dynamic> source) {
        if (out.isNotEmpty) return;
        final usage = pickUsage(source);
        if (usage == null) return;
        final item = asMap(
          usage['usedItem'] ??
              usage['used_item'] ??
              usage['ingredient'] ??
              usage['item'],
        );
        if (item == null) return;

        final rawColl =
            item['collection'] ?? item['coll'] ?? usage['collection'];
        final coll = _normalizeColl(rawColl?.toString());
        final id =
            item['id'] ??
            item['item_id'] ??
            item['itemId'] ??
            item['single_id'] ??
            item['blend_id'];
        if (coll == null || id == null) return;

        final byVariant = asMap(
          usage['usedAmountByVariant'] ??
              usage['used_amount_by_variant'] ??
              usage['usedAmounts'] ??
              usage['used_amounts'],
        );
        var amount = byVariant != null ? amountFromVariant(byVariant) : 0.0;
        if (amount <= 0) {
          amount = d(
            usage['usedAmount'] ??
                usage['used_amount'] ??
                usage['used_grams'] ??
                usage['grams_per_cup'] ??
                usage['gramsPerCup'],
          );
        }
        if (amount <= 0) return;
        acc(coll, id, amount * qty);
      }

      if (usageSource != null) {
        applyUsage(usageSource);
      } else {
        applyUsage(m);
      }
      if (out.isEmpty) {
        final meta = asMap(m['meta']);
        if (meta != null && meta != usageSource) {
          applyUsage(meta);
        }
      }
    }

    return out;
  }

  Future<void> _applyStockDeltaAndUpdate(Map<String, dynamic> updates) async {
    final saleRef = widget.snap.reference;
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
                  TextFormField(
                    controller: _ginsengCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: AppStrings.ginsengGramsLabel,
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
