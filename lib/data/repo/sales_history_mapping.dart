part of 'sales_history_repo.dart';

/// Parsing, mapping, and stock-delta helpers for credit/sales records.
extension _SalesHistoryMapping on SalesHistoryRepository {
  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  double _safeNum(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool _isCreditHidden(Map<String, dynamic> data) {
    return data['credit_hidden'] == true;
  }

  bool _isDeferred(Map<String, dynamic> data) {
    return (data['is_deferred'] ?? data['is_credit'] ?? false) == true;
  }

  bool _isDeferredWithRef(
    Map<String, dynamic> data,
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    if (_isDeferred(data)) return true;
    return ref.parent.id == SalesHistoryRepository._deferredCollection;
  }

  bool _isPaidWithRef(
    Map<String, dynamic> data,
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    final raw = data['paid'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.toLowerCase();
      return v == 'true' || v == '1';
    }
    if (_isDeferredWithRef(data, ref)) return false;
    return true;
  }

  bool _isDeferredDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _isDeferredWithRef(data, doc.reference);
  }

  bool _isPaidDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _isPaidWithRef(data, doc.reference);
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

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
    if (id.isNotEmpty) return id;
    final type = (data['type'] ?? '').toString();
    if (type == 'drink') {
      final fallback =
          data['product_id'] ??
          data['productId'] ??
          data['item_id'] ??
          data['itemId'];
      final fallbackId = fallback?.toString().trim() ?? '';
      return fallbackId.isEmpty ? null : fallbackId;
    }
    return null;
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

  String _resolveSaleType(Map<String, dynamic> data) {
    final rawType = (data['type'] ?? '').toString();
    if (rawType.isNotEmpty) return rawType;
    final linesType = (data['lines_type'] ?? '').toString();
    if (linesType == 'single' || linesType == 'ready_blend') return linesType;
    if (data.containsKey('components')) return 'custom_blend';
    if (data.containsKey('drink_id') || data.containsKey('drink_name')) {
      return 'drink';
    }
    if (data.containsKey('single_id') || data.containsKey('single_name')) {
      return 'single';
    }
    if (data.containsKey('blend_id') || data.containsKey('blend_name')) {
      return 'ready_blend';
    }
    if (data.containsKey('extra_id') || data.containsKey('extra_name')) {
      return 'extra';
    }
    final items = data['items'];
    if (items is List) {
      for (final item in items) {
        if (item is Map &&
            (item.containsKey('grams') || item.containsKey('weight'))) {
          return 'single';
        }
      }
    }
    return '';
  }

  bool _isExtraSale(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    if (type == 'extra') return true;
    return data.containsKey('extra_id') || data.containsKey('extra_name');
  }

  Map<DocumentReference<Map<String, dynamic>>, double> _stockOpsFromSale(
    Map<String, dynamic> data, {
    Map<String, dynamic>? usageSource,
  }) {
    final out = <DocumentReference<Map<String, dynamic>>, double>{};

    void acc(String? coll, dynamic id, double grams) {
      final normalized = _normalizeColl(coll);
      if (normalized == null || id == null || grams <= 0) return;
      final ref = _firestore.collection(normalized).doc(id.toString());
      out[ref] = (out[ref] ?? 0.0) + grams;
    }

    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map) {
        return value.cast<String, dynamic>();
      }
      return null;
    }

    List<Map<String, dynamic>> asList(dynamic value) {
      if (value is List) {
        return value
            .map(
              (e) => e is Map<String, dynamic>
                  ? e
                  : (e is Map
                        ? e.cast<String, dynamic>()
                        : <String, dynamic>{}),
            )
            .toList();
      }
      return const [];
    }

    List<Map<String, dynamic>> lineItems(Map<String, dynamic> m) {
      return [
        ...asList(m['components']),
        ...asList(m['items']),
        ...asList(m['lines']),
        ...asList(m['cart_items']),
        ...asList(m['order_items']),
        ...asList(m['products']),
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
      return row['product_id'] ??
          row['productId'] ??
          row['single_id'] ??
          row['singleId'] ??
          row['blend_id'] ??
          row['blendId'] ??
          row['item_id'] ??
          row['itemId'] ??
          row['id'];
    }

    double gramsFromRow(Map<String, dynamic> row) {
      return _parseDouble(
        row['grams'] ??
            row['weight'] ??
            row['grams_used'] ??
            row['used_grams'] ??
            row['usedGrams'],
      );
    }

    final type = _resolveSaleType(data);
    if (type == 'single' || type == 'ready_blend') {
      final coll = type == 'single' ? 'singles' : 'blends';
      final id =
          data['product_id'] ??
          data['productId'] ??
          data['single_id'] ??
          data['blend_id'] ??
          data['item_id'] ??
          data['id'];
      acc(coll, id, _parseDouble(data['grams']));
    }

    if (out.isEmpty) {
      final rows = lineItems(data);
      for (final row in rows) {
        final grams = gramsFromRow(row);
        if (grams <= 0) continue;
        final coll = collFromRow(row);
        final id = idFromRow(row);
        acc(coll, id, grams);
      }
    }

    if (out.isEmpty && _isDrinkSale(data)) {
      final qtyRaw =
          data['quantity'] ?? data['qty'] ?? data['count'] ?? data['pieces'];
      var qty = _parseDouble(qtyRaw);
      if (qty <= 0) qty = 1;

      final variant =
          (data['variant'] ?? data['drink_variant'] ?? data['size'] ?? '')
              .toString()
              .trim();
      final roast =
          (data['roast'] ?? data['roast_level'] ?? data['roastLevel'] ?? '')
              .toString()
              .trim();
      final variantKey = (variant).toLowerCase();
      final roastKey = (roast).toLowerCase();

      double amountFromVariant(Map<String, dynamic> byVariant) {
        if (variantKey.isEmpty) return 0.0;
        if (byVariant.containsKey(variant)) {
          return _parseDouble(byVariant[variant]);
        }
        for (final entry in byVariant.entries) {
          if (entry.key.toString().trim().toLowerCase() == variantKey) {
            return _parseDouble(entry.value);
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
          amount = _parseDouble(
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
        applyUsage(data);
      }
      if (out.isEmpty) {
        final meta = asMap(data['meta']);
        if (meta != null && meta != usageSource) {
          applyUsage(meta);
        }
      }
    }

    return out;
  }

  List<Map<String, dynamic>> _lineItemsFromSale(Map<String, dynamic> data) {
    List<Map<String, dynamic>> asList(dynamic value) {
      if (value is List) {
        return value
            .map(
              (e) => e is Map<String, dynamic>
                  ? e
                  : (e is Map
                        ? e.cast<String, dynamic>()
                        : <String, dynamic>{}),
            )
            .toList();
      }
      return const [];
    }

    return [
      ...asList(data['components']),
      ...asList(data['items']),
      ...asList(data['lines']),
      ...asList(data['cart_items']),
      ...asList(data['order_items']),
      ...asList(data['products']),
    ];
  }

  void _mergeOps(
    Map<DocumentReference<Map<String, dynamic>>, double> base,
    Map<DocumentReference<Map<String, dynamic>>, double> extra,
  ) {
    for (final entry in extra.entries) {
      base[entry.key] = (base[entry.key] ?? 0.0) + entry.value;
    }
  }

  Future<Map<DocumentReference<Map<String, dynamic>>, double>>
  _drinkOpsFromLineItems(
    Transaction transaction,
    List<Map<String, dynamic>> lineItems,
  ) async {
    if (lineItems.isEmpty) {
      return <DocumentReference<Map<String, dynamic>>, double>{};
    }

    final out = <DocumentReference<Map<String, dynamic>>, double>{};
    final drinkCache = <String, Map<String, dynamic>>{};

    for (final item in lineItems) {
      if (!_isDrinkSale(item)) continue;

      var itemOps = _stockOpsFromSale(item);
      if (itemOps.isEmpty) {
        final drinkId = _drinkIdFromSale(item);
        if (drinkId != null && drinkId.isNotEmpty) {
          Map<String, dynamic>? drinkData = drinkCache[drinkId];
          if (drinkData == null) {
            final drinkRef = _firestore.collection('drinks').doc(drinkId);
            final drinkSnap = await transaction.get(drinkRef);
            drinkData = drinkSnap.data();
            if (drinkData != null) {
              drinkCache[drinkId] = drinkData;
            }
          }
          if (drinkData != null) {
            itemOps = _stockOpsFromSale(item, usageSource: drinkData);
          }
        }
      }

      if (itemOps.isNotEmpty) {
        _mergeOps(out, itemOps);
      }
    }

    return out;
  }

  List<_MutablePaymentEvent> _extractMutablePaymentEvents(
    Map<String, dynamic> data,
  ) {
    final out = <_MutablePaymentEvent>[];
    final raw = data['payment_events'];
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final entry = raw[i];
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final amount = _parseDouble(map['amount']);
        final at = _toTimestamp(map['at']);
        if (amount <= 0 || at == null) continue;
        final id = (map['id'] ?? '').toString().trim();
        out.add(
          _MutablePaymentEvent(id: id, amount: amount, at: at, sourceIndex: i),
        );
      }
      if (out.isNotEmpty) return out;
    }

    final fallbackAmount = _parseDouble(data['last_payment_amount']);
    final fallbackAt = _toTimestamp(data['last_payment_at']);
    if (fallbackAmount > 0 && fallbackAt != null) {
      out.add(
        _MutablePaymentEvent(
          id: '',
          amount: fallbackAmount,
          at: fallbackAt,
          sourceIndex: 0,
          fromFallback: true,
        ),
      );
    }
    return out;
  }

  int _locatePaymentEventIndex(
    List<_MutablePaymentEvent> events, {
    String? eventId,
    int? eventIndex,
    required DateTime eventAt,
    required double amount,
  }) {
    final cleanEventId = (eventId ?? '').trim();
    if (cleanEventId.isNotEmpty) {
      final byId = events.indexWhere((event) => event.id == cleanEventId);
      if (byId >= 0) return byId;
    }

    if (eventIndex != null && eventIndex >= 0) {
      final byIndex = events.indexWhere(
        (event) => event.sourceIndex == eventIndex,
      );
      if (byIndex >= 0) return byIndex;
    }

    final targetMs = eventAt.millisecondsSinceEpoch;
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (!_isAlmostEqual(event.amount, amount)) continue;
      if (event.at.millisecondsSinceEpoch == targetMs) return i;
    }

    return -1;
  }

  List<_MutablePaymentEvent> _normalizedPaymentEvents(
    List<_MutablePaymentEvent> events,
  ) {
    final list = events.where((event) => event.amount > 0).toList()
      ..sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        if (byTime != 0) return byTime;
        return a.sourceIndex.compareTo(b.sourceIndex);
      });

    for (var i = 0; i < list.length; i++) {
      final event = list[i];
      final id = event.id.isNotEmpty ? event.id : _newPaymentEventId();
      list[i] = _MutablePaymentEvent(
        id: id,
        amount: event.amount,
        at: event.at,
        sourceIndex: i,
      );
    }
    return list;
  }

  Map<String, dynamic> _buildPaymentMutationUpdate(
    List<_MutablePaymentEvent> events, {
    required double totalPrice,
  }) {
    final paid = events.fold<double>(
      0.0,
      (totalPaid, event) => totalPaid + event.amount,
    );
    final dueAmount = (totalPrice - paid).clamp(0.0, totalPrice).toDouble();
    final isPaid = dueAmount <= 0.000001;
    final lastEvent = events.isEmpty ? null : events.last;

    final update = <String, dynamic>{
      'is_deferred': true,
      'paid': isPaid,
      'due_amount': dueAmount,
      'payment_events': events
          .map(
            (event) => <String, dynamic>{
              'id': event.id,
              'amount': event.amount,
              'at': event.at,
            },
          )
          .toList(),
    };

    if (lastEvent != null) {
      update['last_payment_at'] = lastEvent.at;
      update['last_payment_amount'] = lastEvent.amount;
    } else {
      update['last_payment_at'] = FieldValue.delete();
      update['last_payment_amount'] = FieldValue.delete();
    }

    if (isPaid && lastEvent != null) {
      update['settled_at'] = lastEvent.at;
    } else {
      update['settled_at'] = FieldValue.delete();
    }

    return update;
  }

  Timestamp? _toTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is num) {
      return Timestamp.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return null;
  }

  bool _isAlmostEqual(double a, double b, {double epsilon = 0.000001}) {
    return (a - b).abs() <= epsilon;
  }

  String _newPaymentEventId() {
    return _firestore
        .collection(SalesHistoryRepository._salesCollection)
        .doc()
        .id;
  }

  double _resolveDueAmount(Map<String, dynamic> data) {
    final raw = data['due_amount'];
    final dueAmount = _parseDouble(raw);
    final totalPrice = _parseDouble(data['total_price']);
    if (dueAmount > 0) {
      if (totalPrice > 0 && dueAmount > totalPrice) {
        return totalPrice;
      }
      return dueAmount;
    }
    if ((data['is_deferred'] == true || data['is_credit'] == true) &&
        data['paid'] != true) {
      return totalPrice;
    }
    return 0;
  }

  List<Map<String, dynamic>> _appendPaymentEvent(
    Map<String, dynamic> data,
    double amount,
    Timestamp at,
  ) {
    final raw = data['payment_events'];
    final List<Map<String, dynamic>> existing = [];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map) {
          final map = entry.cast<String, dynamic>();
          if ((map['id'] ?? '').toString().trim().isEmpty) {
            map['id'] = _newPaymentEventId();
          }
          existing.add(map);
        }
      }
    }
    existing.add({'id': _newPaymentEventId(), 'amount': amount, 'at': at});
    return existing;
  }

  DateTime _createdAtOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final value = data['created_at'];

    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _settledAtOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final value = data['settled_at'];

    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _effectiveAtOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final paid = data['paid'] == true;
    if (paid && data['settled_at'] != null) {
      return _settledAtOf(doc);
    }
    return _createdAtOf(doc);
  }
}

/// Lightweight document wrapper used during transactional credit updates.
class _CreditSaleDoc {
  const _CreditSaleDoc({required this.ref, required this.data});

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;
}

/// Mutable payment-event model used while normalizing mutations.
class _MutablePaymentEvent {
  const _MutablePaymentEvent({
    required this.id,
    required this.amount,
    required this.at,
    required this.sourceIndex,
    this.fromFallback = false,
  });

  final String id;
  final double amount;
  final Timestamp at;
  final int sourceIndex;
  final bool fromFallback;

  _MutablePaymentEvent copyWith({
    String? id,
    double? amount,
    Timestamp? at,
    int? sourceIndex,
    bool? fromFallback,
  }) {
    return _MutablePaymentEvent(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      at: at ?? this.at,
      sourceIndex: sourceIndex ?? this.sourceIndex,
      fromFallback: fromFallback ?? this.fromFallback,
    );
  }
}
