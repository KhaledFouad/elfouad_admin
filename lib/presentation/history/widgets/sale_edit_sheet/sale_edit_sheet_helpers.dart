// ignore_for_file: invalid_use_of_protected_member
part of '../sale_edit_sheet.dart';

/// Parsing, validation, and invoice mapping helpers.
extension _SaleEditSheetHelpers on _SaleEditSheetState {
  double _numOf(dynamic v, [double def = 0.0]) {
    if (v is num) return v.toDouble();
    final raw = '${v ?? ''}'.replaceAll(',', '.');
    return double.tryParse(raw) ?? def;
  }

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

  List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is List) {
      return value
          .map(
            (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
          )
          .toList();
    }
    return const [];
  }

  double _resolveDueAmount(Map<String, dynamic> data, {double? fallbackTotal}) {
    final raw = data['due_amount'];
    final dueAmount = _numOf(raw);
    final totalPrice = fallbackTotal ?? _numOf(data['total_price']);
    if (dueAmount > 0) {
      if (totalPrice > 0 && dueAmount > totalPrice) {
        return totalPrice;
      }
      return dueAmount;
    }
    if ((data['is_deferred'] ?? false) == true && data['paid'] != true) {
      return totalPrice;
    }
    return 0.0;
  }

  double _normalizeDueAmount({
    required double input,
    required double totalPrice,
    required bool isDeferred,
    required bool isPaid,
  }) {
    if (!isDeferred || isPaid) return 0.0;
    if (input > 0) {
      if (totalPrice > 0 && input > totalPrice) return totalPrice;
      return input;
    }
    return totalPrice;
  }

  void _onInvoiceItemChanged() {
    if (!mounted) return;
    setState(_syncInvoiceTotals);
  }

  void _syncInvoiceTotals() {
    final oldTotal = _invoiceTotalPrice;
    final totals = _computeInvoiceTotals(applyComplimentary: _isComplimentary);
    _invoiceTotalPrice = totals.price;
    _invoiceTotalCost = totals.cost;
    _setTotalPriceText(_invoiceTotalPrice);

    if (_isDeferred && !_isPaid) {
      final dueText = _dueAmountCtrl.text.trim();
      final dueValue = _numOf(dueText);
      if (dueText.isEmpty || (dueValue - oldTotal).abs() < 0.01) {
        _dueAmountCtrl.text = _invoiceTotalPrice.toStringAsFixed(2);
      }
    }
  }

  ({double price, double cost}) _computeInvoiceTotals({
    required bool applyComplimentary,
  }) {
    double price = 0.0;
    double cost = 0.0;
    for (final item in _invoiceItems) {
      price += _invoiceLinePrice(item, applyComplimentary: applyComplimentary);
      cost += _invoiceLineCost(item);
    }
    if (applyComplimentary) {
      price = 0.0;
    }
    return (price: price, cost: cost);
  }

  double _invoiceLinePrice(
    _InvoiceItemDraft item, {
    required bool applyComplimentary,
  }) {
    if (applyComplimentary) return 0.0;
    return _numOf(item.priceCtrl.text);
  }

  double _invoiceLineCost(_InvoiceItemDraft item) {
    if (!item.usesMeasure) return item.baseLineCost;
    final measure = item.useGrams
        ? _numOf(item.gramsCtrl.text)
        : _numOf(item.qtyCtrl.text);
    return item.unitCost * measure;
  }

  String _formatQty(double v) {
    if (v == v.roundToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2);
  }

  _InvoiceItemDraft _buildInvoiceItemDraft(Map<String, dynamic> raw) {
    final item = Map<String, dynamic>.from(raw);
    final component = SaleComponent.fromMap(item);
    final label = component.label.isNotEmpty
        ? component.label
        : AppStrings.noNameLabel;

    double pickNum(List<String> keys) {
      for (final key in keys) {
        if (item.containsKey(key)) {
          final v = _numOf(item[key]);
          if (v != 0) return v;
        }
      }
      return 0.0;
    }

    final grams = _numOf(item['grams'] ?? item['weight']);
    final qty = _numOf(
      item['qty'] ?? item['quantity'] ?? item['count'] ?? item['pieces'],
    );
    final unit = (item['unit'] ?? '').toString();
    final unitKey = unit.trim().toLowerCase();
    final showGrams = grams > 0 || unitKey == 'g';
    final showQty =
        qty > 0 ||
        item.containsKey('qty') ||
        item.containsKey('quantity') ||
        item.containsKey('count') ||
        item.containsKey('pieces');
    final useGrams = showGrams && (unitKey == 'g' || grams > 0 || !showQty);
    final measure = useGrams ? grams : qty;

    final linePrice = pickNum(const [
      'line_total_price',
      'total_price',
      'price',
      'line_price',
      'amount',
      'total',
      'subtotal',
    ]);
    final lineCost = pickNum(const [
      'line_total_cost',
      'total_cost',
      'cost',
      'line_cost',
      'cost_amount',
    ]);

    double unitPrice = _numOf(item['unit_price'] ?? item['price_per_unit']);
    if (unitPrice <= 0 && useGrams) {
      final perG = _numOf(item['price_per_g']);
      final perKg = _numOf(item['price_per_kg']);
      if (perG > 0) {
        unitPrice = perG;
      } else if (perKg > 0) {
        unitPrice = perKg / 1000.0;
      }
    }
    if (unitPrice <= 0 && measure > 0) {
      unitPrice = linePrice > 0 ? (linePrice / measure) : 0.0;
    }
    if (!showGrams && !showQty) {
      unitPrice = linePrice;
    }

    double unitCost = _numOf(item['unit_cost'] ?? item['cost_per_unit']);
    if (unitCost <= 0 && useGrams) {
      final perG = _numOf(item['cost_per_g']);
      final perKg = _numOf(item['cost_per_kg']);
      if (perG > 0) {
        unitCost = perG;
      } else if (perKg > 0) {
        unitCost = perKg / 1000.0;
      }
    }
    if (unitCost <= 0 && measure > 0) {
      unitCost = lineCost > 0 ? (lineCost / measure) : 0.0;
    }

    final meta = item['meta'];
    final metaMap = meta is Map ? meta.cast<String, dynamic>() : {};
    final ginsengGrams = _intOf(
      item['ginseng_grams'] ??
          item['ginsengGrams'] ??
          metaMap['ginseng_grams'] ??
          metaMap['ginsengGrams'],
      0,
    );
    final showGinseng =
        ginsengGrams > 0 ||
        item.containsKey('ginseng_grams') ||
        item.containsKey('ginsengGrams') ||
        metaMap.containsKey('ginseng_grams') ||
        metaMap.containsKey('ginsengGrams');

    final gramsCtrl = TextEditingController(
      text: grams > 0 ? grams.toStringAsFixed(0) : '',
    );
    final qtyCtrl = TextEditingController(text: qty > 0 ? _formatQty(qty) : '');
    double displayPrice = linePrice;
    if (displayPrice <= 0 && unitPrice > 0) {
      if (showGrams || showQty) {
        displayPrice = (measure > 0) ? unitPrice * measure : unitPrice;
      } else {
        displayPrice = unitPrice;
      }
    }
    final priceCtrl = TextEditingController(
      text: displayPrice > 0 ? displayPrice.toStringAsFixed(2) : '',
    );
    final ginsengCtrl = TextEditingController(
      text: ginsengGrams > 0 ? ginsengGrams.toString() : '',
    );

    return _InvoiceItemDraft(
      raw: item,
      label: label,
      unit: unit,
      showGrams: showGrams,
      showQty: showQty,
      useGrams: useGrams,
      spicedEnabled: component.spicedEnabled == true,
      spiced: component.spiced ?? false,
      showGinseng: showGinseng,
      unitCost: unitCost,
      baseLineCost: lineCost,
      priceCtrl: priceCtrl,
      qtyCtrl: qtyCtrl,
      gramsCtrl: gramsCtrl,
      ginsengCtrl: ginsengCtrl,
    );
  }

  void _initInvoiceFields() {
    _isDeferred = (_m['is_deferred'] ?? false) == true;
    _isPaid = (_m['paid'] ?? (!_isDeferred)) == true;
    if (_isDeferred && _isComplimentary) {
      _isComplimentary = false;
    }
    final dueAmount = _resolveDueAmount(
      _m,
      fallbackTotal: _numOf(_m['total_price']),
    );
    if (dueAmount > 0 || _m.containsKey('due_amount')) {
      _dueAmountCtrl.text = dueAmount.toStringAsFixed(2);
    }

    final items = _asListMap(_m['items']);
    for (final raw in items) {
      final draft = _buildInvoiceItemDraft(raw);
      _invoiceItems.add(draft);
      draft.priceCtrl.addListener(_onInvoiceItemChanged);
      draft.qtyCtrl.addListener(_onInvoiceItemChanged);
      draft.gramsCtrl.addListener(_onInvoiceItemChanged);
    }
    _syncInvoiceTotals();
  }

  void _setTotalPriceText(double v) {
    final s = v.toStringAsFixed(2);
    if (_totalPriceCtrl.text != s) {
      _totalPriceCtrl.text = s;
      _totalPriceCtrl.selection = TextSelection.collapsed(offset: s.length);
    }
  }
}
