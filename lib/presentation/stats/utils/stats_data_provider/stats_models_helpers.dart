// ignore_for_file: unused_element
part of '../stats_data_provider.dart';

/// Mapping and normalization helpers shared across stats computations.
double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

bool _readBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final raw = v.toLowerCase();
    return raw == 'true' || raw == '1';
  }
  return false;
}

bool _boolish(dynamic v, {required bool fallback}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final raw = v.trim().toLowerCase();
    if (raw == 'true' || raw == '1') return true;
    if (raw == 'false' || raw == '0') return false;
  }
  return fallback;
}

Map<String, dynamic> _metaOf(Map<String, dynamic> m) {
  final v = m['meta'];
  if (v is Map) return v.cast<String, dynamic>();
  return const {};
}

bool _isSpicedFrom(Map<String, dynamic> m) {
  final meta = _metaOf(m);

  bool? spicedEnabled;
  if (meta.containsKey('spicedEnabled')) {
    spicedEnabled = _readBool(meta['spicedEnabled']);
  } else if (m.containsKey('spicedEnabled')) {
    spicedEnabled = _readBool(m['spicedEnabled']);
  }

  bool? spicedVal;
  if (meta.containsKey('spiced')) {
    spicedVal = _readBool(meta['spiced']);
  } else if (m.containsKey('spiced')) {
    spicedVal = _readBool(m['spiced']);
  } else if (m.containsKey('is_spiced')) {
    spicedVal = _readBool(m['is_spiced']);
  }

  if (spicedEnabled == null && spicedVal == true) {
    spicedEnabled = true;
  }

  if (spicedEnabled == true) return spicedVal ?? false;
  return false;
}

bool _isTurkishCoffeeName(String name) {
  final n = name.toLowerCase();
  return n.contains('تركي') || n.contains('تركى') || n.contains('turk');
}

double _drinkGramsFromSale(Map<String, dynamic> m) {
  double grams = _pickNum(m, [
    'grams',
    'total_grams',
    'used_grams',
    'grams_used',
    'usedGrams',
  ]);
  if (grams > 0) return grams;

  final meta = _metaOf(m);
  grams = _pickNum(meta, [
    'grams',
    'total_grams',
    'used_grams',
    'grams_used',
    'usedGrams',
  ]);
  if (grams > 0) return grams;

  final perCup = _pickNum(m, [
    'used_amount',
    'usedAmount',
    'grams_per_cup',
    'gramsPerCup',
  ]);
  final metaPerCup = _pickNum(meta, [
    'used_amount',
    'usedAmount',
    'grams_per_cup',
    'gramsPerCup',
  ]);
  final amountPerCup = perCup > 0 ? perCup : metaPerCup;
  if (amountPerCup <= 0) return 0.0;

  final qty = _d(m['quantity'] ?? m['qty'] ?? m['count'] ?? m['pieces']);
  final cups = qty > 0 ? qty : 1;
  return amountPerCup * cups;
}

const Set<String> _knownTypes = {
  'drink',
  'single',
  'ready_blend',
  'custom_blend',
  'extra',
};

bool _isKnownType(String t) => _knownTypes.contains(t);

double? _numIfPresent(Map<String, dynamic> m, String key) {
  if (!m.containsKey(key)) return null;
  final v = m[key];
  if (v == null) return null;
  return _d(v);
}

bool _hasAnyKey(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null) return true;
  }
  return false;
}

double _pickNum(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = _numIfPresent(m, k);
    if (v != null) return v;
  }
  return 0.0;
}

String _pickStr(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (!m.containsKey(k)) continue;
    final v = m[k];
    if (v == null) continue;
    return v.toString();
  }
  return '';
}

List<Map<String, dynamic>> _asListMap(dynamic v) {
  if (v is List) {
    return v
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .toList();
  }
  return const [];
}

List<Map<String, dynamic>> _extractLineItems(Map<String, dynamic> m) {
  return [
    ..._asListMap(m['components']),
    ..._asListMap(m['items']),
    ..._asListMap(m['lines']),
    ..._asListMap(m['cart_items']),
    ..._asListMap(m['order_items']),
    ..._asListMap(m['products']),
  ];
}

Map<String, dynamic> _normalizeLineItem(Map<String, dynamic> c) {
  final out = Map<String, dynamic>.from(c);
  final qty = _pickNum(out, ['qty', 'quantity', 'count', 'pieces']);
  final grams = _pickNum(out, ['grams', 'weight', 'gram', 'total_grams']);
  final unit = _pickStr(out, ['unit', 'uom', 'unit_name']);
  const priceKeys = [
    'line_total_price',
    'total_price',
    'price',
    'line_price',
    'amount',
    'total',
    'subtotal',
  ];
  const costKeys = [
    'line_total_cost',
    'total_cost',
    'cost',
    'line_cost',
    'cost_amount',
  ];
  final hasLinePrice = _hasAnyKey(out, priceKeys);
  final hasLineCost = _hasAnyKey(out, costKeys);
  var linePrice = _pickNum(out, priceKeys);
  var lineCost = _pickNum(out, costKeys);
  final unitPrice = _pickNum(out, ['unit_price', 'price_per_unit']);
  final unitCost = _pickNum(out, ['unit_cost', 'cost_per_unit']);

  if (!hasLinePrice && unitPrice > 0 && qty > 0) {
    linePrice = unitPrice * qty;
  }
  if (!hasLineCost && unitCost > 0 && qty > 0) {
    lineCost = unitCost * qty;
  }

  final name = _pickStr(out, [
    'name',
    'item_name',
    'product_name',
    'drink_name',
    'single_name',
    'blend_name',
    'title',
  ]).trim();
  final variant = _pickStr(out, ['variant', 'roast', 'size']).trim();
  final unitValue = unit.isNotEmpty ? unit : (grams > 0 ? 'g' : '');

  if (name.isNotEmpty) {
    out['name'] = name;
  } else {
    out.remove('name');
  }
  if (variant.isNotEmpty) {
    out['variant'] = variant;
  } else {
    out.remove('variant');
  }
  out['qty'] = qty;
  out['quantity'] = qty;
  out['grams'] = grams;
  if (unitValue.isNotEmpty) {
    out['unit'] = unitValue;
  } else {
    out.remove('unit');
  }
  out['line_total_price'] = linePrice;
  out['line_total_cost'] = lineCost;
  return out;
}

String _inferLineType(Map<String, dynamic> c, {String? fallbackType}) {
  final raw = (c['type'] ?? c['line_type'] ?? c['item_type'] ?? '').toString();
  if (_isKnownType(raw)) return raw;

  if (c.containsKey('extra_id') || (c['is_extra'] ?? false) == true) {
    return 'extra';
  }
  final unit = (c['unit'] ?? '').toString();
  if (unit == 'piece') return 'extra';

  if (c.containsKey('drink_id') || c.containsKey('drink_name')) {
    return 'drink';
  }
  if (c.containsKey('blend_id') ||
      c.containsKey('blend_name') ||
      c['lines_type'] == 'ready_blend') {
    return 'ready_blend';
  }
  if (c.containsKey('single_id') ||
      c.containsKey('single_name') ||
      c['lines_type'] == 'single') {
    return 'single';
  }

  final grams = _d(c['grams']);
  if (grams > 0) return 'single';
  final qty = _d(c['qty'] ?? c['quantity']);
  if (qty > 0) return 'drink';

  return fallbackType ?? 'unknown';
}

Map<String, dynamic> _applyTotalsFallback(
  Map<String, dynamic> m, {
  List<Map<String, dynamic>>? lines,
}) {
  final out = Map<String, dynamic>.from(m);
  final isComplimentary = (out['is_complimentary'] ?? false) == true;

  double price = _pickNum(out, ['total_price']);
  if (price <= 0) {
    price = _pickNum(out, ['total', 'total_amount', 'amount', 'grand_total']);
  }
  double cost = _pickNum(out, ['total_cost']);
  if (cost <= 0) {
    cost = _pickNum(out, ['total_cost_amount', 'cost', 'totalCost']);
  }
  double profit = _pickNum(out, ['profit_total', 'profit']);

  if (lines != null && lines.isNotEmpty) {
    final linePrice = lines.fold<double>(
      0.0,
      (s, r) => s + _d(r['line_total_price']),
    );
    final lineCost = lines.fold<double>(
      0.0,
      (s, r) => s + _d(r['line_total_cost']),
    );
    if (price <= 0 && linePrice > 0) price = linePrice;
    if (cost <= 0 && lineCost > 0) cost = lineCost;
  }

  if (isComplimentary) {
    price = 0.0;
    profit = 0.0;
  }

  if (profit == 0 && (price > 0 || cost > 0)) {
    profit = price - cost;
  }

  if (price > 0 || out.containsKey('total_price')) out['total_price'] = price;
  if (cost > 0 || out.containsKey('total_cost')) out['total_cost'] = cost;
  if (profit != 0 || out.containsKey('profit_total')) {
    out['profit_total'] = profit;
  }
  return out;
}

const List<String> _parentFinancialKeys = [
  'is_deferred',
  'is_credit',
  'paid',
  'due_amount',
  'payment_events',
  'last_payment_amount',
  'last_payment_at',
  'settled_at',
  'updated_at',
  'created_at',
  'original_created_at',
  'is_complimentary',
];

List<Map<String, dynamic>> _expandCartSales(List<Map<String, dynamic>> data) {
  final out = <Map<String, dynamic>>[];
  for (final m in data) {
    final fixed = _applyTotalsFallback(m);
    fixed['is_spiced'] = _isSpicedFrom(fixed);
    final type = (fixed['type'] ?? '').toString();
    final rawLines = _extractLineItems(fixed);
    final isComplimentary = (fixed['is_complimentary'] ?? false) == true;

    if (rawLines.isEmpty || _isKnownType(type)) {
      out.add(fixed);
      continue;
    }

    final lines = rawLines.map(_normalizeLineItem).toList();
    final lineTotal = lines.fold<double>(
      0.0,
      (s, r) => s + _d(r['line_total_price']),
    );
    final lineCostTotal = lines.fold<double>(
      0.0,
      (s, r) => s + _d(r['line_total_cost']),
    );
    final parentTotal = _d(fixed['total_price']);
    final tolerance = parentTotal > 0 ? parentTotal * 0.01 : 0.0;
    final withinTolerance =
        parentTotal <= 0 || (lineTotal - parentTotal).abs() <= tolerance;
    final hasLineValue = lineTotal > 0 || lineCostTotal > 0;
    final shouldExpand = isComplimentary ? lines.isNotEmpty : hasLineValue;
    if (!shouldExpand || (!isComplimentary && !withinTolerance)) {
      out.add(_applyTotalsFallback(fixed, lines: lines));
      continue;
    }

    final saleId = (fixed['sale_id'] ?? fixed['id'] ?? '').toString();
    for (final line in lines) {
      final lineType = _inferLineType(
        line,
        fallbackType: type.isNotEmpty ? type : null,
      );
      final merged = Map<String, dynamic>.from(fixed);
      merged.addAll(line);
      for (final key in _parentFinancialKeys) {
        if (fixed.containsKey(key)) {
          merged[key] = fixed[key];
        }
      }
      merged['is_spiced'] = _isSpicedFrom(merged);
      merged['type'] = lineType;
      if (saleId.isNotEmpty) merged['sale_id'] = saleId;
      merged['parent_total_price'] = _d(fixed['total_price']);
      merged['parent_total_cost'] = _d(fixed['total_cost']);
      merged['parent_profit_total'] = _d(fixed['profit_total']);

      var linePrice = _d(line['line_total_price']);
      final lineCost = _d(line['line_total_cost']);
      if (isComplimentary) {
        linePrice = 0.0;
      }
      merged['total_price'] = linePrice;
      merged['total_cost'] = lineCost;
      merged['profit_total'] = linePrice - lineCost;

      if (lineType == 'drink' || lineType == 'extra') {
        final qty = _d(line['qty'] ?? line['quantity']);
        if (qty > 0) merged['quantity'] = qty;
      }
      if (lineType == 'single' || lineType == 'ready_blend') {
        final grams = _d(line['grams']);
        if (grams > 0) merged['grams'] = grams;
      }

      out.add(merged);
    }
  }
  return out;
}

List<Map<String, dynamic>> _prepareStatsData(List<Map<String, dynamic>> data) {
  return _expandCartSales(data);
}

DateTime _asUtc(dynamic v) {
  if (v is DateTime) return v.toUtc();
  try {
    // Firestore Timestamp (dynamic)
    // ignore: avoid_dynamic_calls
    if (v != null && v.toDate != null) {
      // ignore: avoid_dynamic_calls
      final dt = v.toDate();
      if (dt is DateTime) return dt.toUtc();
    }
  } catch (_) {}
  if (v is num) {
    final raw = v.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  if (v is String) {
    return DateTime.tryParse(v)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime _productionUtc(Map<String, dynamic> m) {
  final orig = m['original_created_at'];
  final origUtc = orig == null ? null : _asUtc(orig);
  if (origUtc != null && origUtc.millisecondsSinceEpoch > 0) return origUtc;
  return _asUtc(m['created_at']);
}

DateTime _financialUtc(Map<String, dynamic> m) {
  final created = _asUtc(m['created_at']);
  final settledRaw = m['settled_at'];
  final settled = settledRaw == null ? null : _asUtc(settledRaw);
  final updatedRaw = m['updated_at'];
  final updated = updatedRaw == null ? null : _asUtc(updatedRaw);
  final lastPaymentRaw = m['last_payment_at'];
  final lastPayment = lastPaymentRaw == null ? null : _asUtc(lastPaymentRaw);

  final isDeferred = _boolish(m['is_deferred'], fallback: false);
  final paid = _boolish(m['paid'], fallback: !isDeferred);

  if (isDeferred &&
      lastPayment != null &&
      lastPayment.millisecondsSinceEpoch > 0) {
    return lastPayment;
  }
  if (paid) {
    if (settled != null && settled.millisecondsSinceEpoch > 0) {
      return settled;
    }
    if (updated != null && updated.millisecondsSinceEpoch > 0) {
      return updated;
    }
  }
  return created;
}

bool _inRangeUtc(DateTime ts, DateTime start, DateTime end) {
  final afterOrEqual = ts.isAtSameMomentAs(start) || ts.isAfter(start);
  final before = ts.isBefore(end); // end حصري
  return afterOrEqual && before;
}

double _resolvedSalePrice(Map<String, dynamic> m) {
  final isComplimentary = (m['is_complimentary'] ?? false) == true;
  if (isComplimentary) return 0.0;
  return _d(m['total_price']);
}

double _resolvedSaleCost(Map<String, dynamic> m) => _d(m['total_cost']);

double _resolvedSaleProfit(
  Map<String, dynamic> m, {
  double? resolvedPrice,
  double? resolvedCost,
}) {
  final isComplimentary = (m['is_complimentary'] ?? false) == true;
  if (isComplimentary) return 0.0;
  final price = resolvedPrice ?? _resolvedSalePrice(m);
  final cost = resolvedCost ?? _resolvedSaleCost(m);
  var profit = _d(m['profit_total']);
  if (profit == 0 && (price != 0 || cost != 0)) {
    profit = price - cost;
  }
  return profit;
}

List<Map<String, dynamic>> _paymentEvents(Map<String, dynamic> m) {
  final raw = m['payment_events'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

double _deferredPaidAmountInRange(
  Map<String, dynamic> m,
  DateTime startUtc,
  DateTime endUtc,
) {
  final events = _paymentEvents(m);
  if (events.isNotEmpty) {
    var sum = 0.0;
    for (final event in events) {
      final amount = _d(event['amount']);
      if (amount <= 0) continue;
      final atRaw = event['at'] ?? event['paid_at'] ?? event['created_at'];
      if (atRaw == null) continue;
      final at = _asUtc(atRaw);
      if (_inRangeUtc(at, startUtc, endUtc)) {
        sum += amount;
      }
    }
    return sum;
  }

  final lastAmount = _d(m['last_payment_amount']);
  if (lastAmount <= 0) return 0.0;
  final lastAtRaw = m['last_payment_at'];
  if (lastAtRaw == null) return 0.0;
  final lastAt = _asUtc(lastAtRaw);
  return _inRangeUtc(lastAt, startUtc, endUtc) ? lastAmount : 0.0;
}

bool _hasDeferredPaymentTracking(Map<String, dynamic> m) {
  if (!_boolish(m['is_deferred'], fallback: false)) return false;
  if (_paymentEvents(m).isNotEmpty) return true;
  if (_d(m['last_payment_amount']) <= 0) return false;
  return m['last_payment_at'] != null;
}

double _financialRatioBasePrice(Map<String, dynamic> m) {
  final parentTotal = _d(m['parent_total_price']);
  if (parentTotal > 0) return parentTotal;
  return _resolvedSalePrice(m);
}

double _financialFactorForRange(
  Map<String, dynamic> m,
  DateTime startUtc,
  DateTime endUtc,
) {
  final isDeferred = _boolish(m['is_deferred'], fallback: false);
  final paid = _boolish(m['paid'], fallback: !isDeferred);

  if (isDeferred && _hasDeferredPaymentTracking(m)) {
    final paidAmount = _deferredPaidAmountInRange(m, startUtc, endUtc);
    if (paidAmount <= 0) return 0.0;
    final base = _financialRatioBasePrice(m);
    if (base <= 0) return 0.0;
    final ratio = paidAmount / base;
    if (ratio.isNaN || ratio.isInfinite) return 0.0;
    return ratio.clamp(0.0, 1.0);
  }

  final finInRange = _inFinancialRange(m, startUtc, endUtc);
  return (finInRange && (!isDeferred || paid)) ? 1.0 : 0.0;
}

bool _isUnpaidDeferred(Map<String, dynamic> m) {
  final isDeferred = _boolish(m['is_deferred'], fallback: false);
  final paid = _boolish(m['paid'], fallback: !isDeferred);
  return isDeferred && !paid;
}

bool _inProductionRange(Map<String, dynamic> m, DateTime start, DateTime end) =>
    _inRangeUtc(_productionUtc(m), start, end);

bool _inFinancialRange(Map<String, dynamic> m, DateTime start, DateTime end) =>
    _inRangeUtc(_financialUtc(m), start, end);
