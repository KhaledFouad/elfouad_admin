import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/services/archive/archive_service.dart';
import 'package:flutter/material.dart';

class SalesPageResult {
  SalesPageResult({
    required this.docs,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class SalesHistoryRepository {
  SalesHistoryRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const int pageSize = 30;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCreatedInRange(
    DateTimeRange range,
  ) {
    return _firestore
        .collection('sales')
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('created_at', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSettledInRange(
    DateTimeRange range,
  ) {
    return _firestore
        .collection('sales')
        .where(
          'settled_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('settled_at', isLessThan: Timestamp.fromDate(range.end))
        .snapshots();
  }

  // صفحة واحدة (للـ List مع "عرض المزيد")
  Future<SalesPageResult> fetchPage({
    required DateTimeRange range,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final baseQuery = _firestore
        .collection('sales')
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('created_at', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('created_at', descending: true);

    var pagedQuery = baseQuery.limit(pageSize);
    if (startAfter != null) {
      pagedQuery = pagedQuery.startAfterDocument(startAfter);
    }

    final baseSnap = await pagedQuery.get();
    var docs = baseSnap.docs;

    // أول صفحة: ضيف معاها الفواتير المؤجلة الغير مسددة
    if (startAfter == null) {
      final settledFuture = _firestore
          .collection('sales')
          .where(
            'settled_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where('settled_at', isLessThan: Timestamp.fromDate(range.end))
          .orderBy('settled_at', descending: true)
          .get();

      final deferredFuture = _firestore
          .collection('sales')
          .where('is_deferred', isEqualTo: true)
          .where('paid', isEqualTo: false)
          .get();

      final settledSnap = await settledFuture;
      final deferredSnap = await deferredFuture;

      if (deferredSnap.docs.isNotEmpty || settledSnap.docs.isNotEmpty) {
        final combined =
            <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final d in docs) {
          combined[d.id] = d;
        }
        for (final d in deferredSnap.docs) {
          combined[d.id] = d;
        }
        for (final d in settledSnap.docs) {
          combined[d.id] = d;
        }
        docs = combined.values.toList()
          ..sort((a, b) => _effectiveAtOf(b).compareTo(_effectiveAtOf(a)));
      }
    }

    final hasMore = baseSnap.docs.length == pageSize;
    final lastDoc = baseSnap.docs.isNotEmpty ? baseSnap.docs.last : startAfter;

    return SalesPageResult(docs: docs, lastDoc: lastDoc, hasMore: hasMore);
  }

  /// استعلام بدون Limit — بنستعمله علشان نحسب إجمالي اليوم كله للـ Summary
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllForRange({
    required DateTimeRange range,
  }) async {
    final createdFuture = _firestore
        .collection('sales')
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('created_at', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('created_at', descending: true)
        .get();

    final settledFuture = _firestore
        .collection('sales')
        .where(
          'settled_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('settled_at', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('settled_at', descending: true)
        .get();

    final createdSnap = await createdFuture;
    final settledSnap = await settledFuture;

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in createdSnap.docs) {
      combined[d.id] = d;
    }
    for (final d in settledSnap.docs) {
      combined[d.id] = d;
    }

    return combined.values.toList();
  }

  Future<void> settleDeferredSale(String saleId) async {
    final ref = _firestore.collection('sales').doc(saleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Sale not found');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final bool isDeferred =
          data['is_deferred'] == true || data['is_credit'] == true;
      final double dueAmount = _resolveDueAmount(data);

      if (!isDeferred || dueAmount <= 0) {
        throw Exception('Not a valid deferred sale.');
      }

      final double totalCost = _parseDouble(data['total_cost']);
      final double totalPrice = _parseDouble(data['total_price']);

      final components = (data['components'] as List?)
          ?.map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      if (components != null && components.isNotEmpty) {
        for (final component in components) {
          final grams = _parseDouble(component['grams']);
          final pricePerKg = _parseDouble(component['price_per_kg']);
          double pricePerGram = _parseDouble(component['price_per_g']);

          if (pricePerGram <= 0 && pricePerKg > 0) {
            pricePerGram = pricePerKg / 1000.0;
            component['price_per_g'] = pricePerGram;
            component['line_total_price'] = pricePerGram * grams;
          }
        }
        transaction.update(ref, {'components': components});
      }

      final newProfit = totalPrice - totalCost;
      final now = Timestamp.now();
      final paymentEvents = _appendPaymentEvent(data, dueAmount, now);

      transaction.update(ref, {
        'profit_total': newProfit,
        'is_deferred': true,
        'paid': true,
        'due_amount': 0.0,
        'settled_at': FieldValue.serverTimestamp(),
        'last_payment_at': now,
        'last_payment_amount': dueAmount,
        'payment_events': paymentEvents,
      });
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchCreditSales() async {
    final deferredFuture = _firestore
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .get();

    final creditFuture = _firestore
        .collection('sales')
        .where('is_credit', isEqualTo: true)
        .get();

    final settledFuture = _firestore
        .collection('sales')
        .where('settled_at', isNull: false)
        .get();

    final results = await Future.wait([
      deferredFuture,
      creditFuture,
      settledFuture,
    ]);
    final deferredSnap = results[0];
    final creditSnap = results[1];
    final settledSnap = results[2];

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in creditSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in settledSnap.docs) {
      combined[doc.id] = doc;
    }

    final filtered = combined.values.where((doc) {
      final data = doc.data();
      return !_isCreditHidden(data);
    }).toList();
    return filtered;
  }

  Future<List<String>> fetchCreditCustomerNames() async {
    final docs = await fetchCreditSales();
    final names = <String>{};
    for (final doc in docs) {
      final name = (doc.data()['note'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<int> fetchUnpaidCreditCount() async {
    final deferredFuture = _firestore
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .get();

    final creditFuture = _firestore
        .collection('sales')
        .where('is_credit', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .get();

    final results = await Future.wait([deferredFuture, creditFuture]);
    final deferredSnap = results[0];
    final creditSnap = results[1];

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in creditSnap.docs) {
      combined[doc.id] = doc;
    }

    var count = 0;
    for (final doc in combined.values) {
      if (!_isCreditHidden(doc.data())) {
        count++;
      }
    }
    return count;
  }

  Future<void> hideCreditCustomer(String customerName) async {
    final name = customerName.trim();
    if (name.isEmpty) {
      throw Exception('Customer name is required.');
    }

    final snap = await _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .get();

    if (snap.docs.isEmpty) {
      return;
    }

    const batchLimit = 400;
    var batch = _firestore.batch();
    var opCount = 0;
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'credit_hidden': true,
        'credit_hidden_at': FieldValue.serverTimestamp(),
      });
      opCount++;
      if (opCount >= batchLimit) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) {
      await batch.commit();
    }
  }

  Future<void> deleteCreditCustomer(String customerName) async {
    final name = customerName.trim();
    if (name.isEmpty) {
      throw Exception('Customer name is required.');
    }

    final deferredFuture = _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .where('is_deferred', isEqualTo: true)
        .get();

    final creditFuture = _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .where('is_credit', isEqualTo: true)
        .get();

    final results = await Future.wait([deferredFuture, creditFuture]);
    final deferredSnap = results[0];
    final creditSnap = results[1];

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in creditSnap.docs) {
      combined[doc.id] = doc;
    }

    if (combined.isEmpty) {
      return;
    }

    for (final doc in combined.values) {
      await archiveThenDelete(
        srcRef: doc.reference,
        kind: 'sale',
        reason: 'credit_customer_delete',
      );
    }
  }

  Future<void> deleteSaleWithRollback(String saleId) async {
    final saleRef = _firestore.collection('sales').doc(saleId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(saleRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};

      var ops = _stockOpsFromSale(data);
      if (ops.isEmpty && _isDrinkSale(data)) {
        final drinkId = _drinkIdFromSale(data);
        if (drinkId != null && drinkId.isNotEmpty) {
          final drinkRef = _firestore.collection('drinks').doc(drinkId);
          final drinkSnap = await transaction.get(drinkRef);
          final drinkData = drinkSnap.data();
          if (drinkData != null) {
            ops = _stockOpsFromSale(data, usageSource: drinkData);
          }
        }
      }
      final missingStockRefs = <String>[];
      for (final entry in ops.entries) {
        final ref = entry.key;
        final grams = entry.value;
        if (grams <= 0) continue;

        final stockSnap = await transaction.get(ref);
        if (!stockSnap.exists) {
          missingStockRefs.add(ref.path);
          continue;
        }
        final stockData = stockSnap.data() ?? <String, dynamic>{};
        final current = _safeNum(stockData['stock']);
        transaction.update(ref, {
          'stock': current + grams,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (_isExtraSale(data)) {
        final qty = _parseInt(data['quantity']);
        final extraId = data['extra_id']?.toString() ?? '';
        if (qty > 0 && extraId.isNotEmpty) {
          final extraRef = _firestore.collection('extras').doc(extraId);
          final extraSnap = await transaction.get(extraRef);
          if (extraSnap.exists) {
            final extra = extraSnap.data() ?? <String, dynamic>{};
            final current = _parseInt(extra['stock_units']);
            transaction.update(extraRef, {
              'stock_units': current + qty,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      final archiveRef =
          _firestore.collection(archiveBinCollection).doc();
      final archiveData = buildArchiveEntry(
        srcRef: saleRef,
        kind: 'sale',
        data: data,
        reason: 'manual_delete',
      );
      archiveData['rollback_missing_refs'] = missingStockRefs;
      archiveData['rollback_ops_count'] = ops.length;
      archiveData['rollback_applied_count'] =
          ops.length - missingStockRefs.length;
      transaction.set(archiveRef, archiveData);
      transaction.delete(saleRef);
    });
  }

  Future<void> restoreSaleFromArchive(
    DocumentReference<Map<String, dynamic>> archiveRef,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final archiveSnap = await transaction.get(archiveRef);
      if (!archiveSnap.exists) return;
      final archiveData = archiveSnap.data() ?? <String, dynamic>{};

      final originalPath = archiveData['original_path']?.toString() ?? '';
      final rawSale = archiveData['data'];
      if (originalPath.isEmpty || rawSale is! Map) return;
      final saleData = rawSale.cast<String, dynamic>();

      final saleRef = _firestore.doc(originalPath);

      var ops = _stockOpsFromSale(saleData);
      if (ops.isEmpty && _isDrinkSale(saleData)) {
        final drinkId = _drinkIdFromSale(saleData);
        if (drinkId != null && drinkId.isNotEmpty) {
          final drinkRef = _firestore.collection('drinks').doc(drinkId);
          final drinkSnap = await transaction.get(drinkRef);
          final drinkData = drinkSnap.data();
          if (drinkData != null) {
            ops = _stockOpsFromSale(saleData, usageSource: drinkData);
          }
        }
      }
      for (final entry in ops.entries) {
        final grams = entry.value;
        if (grams > 0) {
          transaction.update(entry.key, {
            'stock': FieldValue.increment(-grams),
          });
        }
      }

      if (_isExtraSale(saleData)) {
        final qty = _parseInt(saleData['quantity']);
        final extraId = saleData['extra_id']?.toString() ?? '';
        if (qty > 0 && extraId.isNotEmpty) {
          final extraRef = _firestore.collection('extras').doc(extraId);
          final extraSnap = await transaction.get(extraRef);
          if (extraSnap.exists) {
            final extra = extraSnap.data() ?? <String, dynamic>{};
            final current = _parseInt(extra['stock_units']);
            if (current < qty) {
              throw Exception('Insufficient extra stock to restore sale.');
            }
            transaction.update(extraRef, {
              'stock_units': current - qty,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      transaction.set(saleRef, saleData);
      transaction.delete(archiveRef);
    });
  }

  Future<void> applyCreditPayment({
    required String customerName,
    required double amount,
  }) async {
    final name = customerName.trim();
    if (name.isEmpty) {
      throw Exception('Customer name is required.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw Exception('Invalid payment amount.');
    }

    final deferredFuture = _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .where('is_deferred', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .get();

    final creditFuture = _firestore
        .collection('sales')
        .where('note', isEqualTo: name)
        .where('is_credit', isEqualTo: true)
        .where('paid', isEqualTo: false)
        .get();

    final results = await Future.wait([deferredFuture, creditFuture]);
    final deferredSnap = results[0];
    final creditSnap = results[1];

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in creditSnap.docs) {
      combined[doc.id] = doc;
    }

    if (combined.isEmpty) {
      return;
    }

    final docs = combined.values.toList()
      ..sort((a, b) => _createdAtOf(a).compareTo(_createdAtOf(b)));

    await _firestore.runTransaction((transaction) async {
      var remaining = amount;
      final liveSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in docs) {
        liveSnaps.add(await transaction.get(doc.reference));
      }

      for (final liveSnap in liveSnaps) {
        if (remaining <= 0) break;
        if (!liveSnap.exists) continue;
        final data = liveSnap.data() as Map<String, dynamic>;
        final dueAmount = _resolveDueAmount(data);
        if (dueAmount <= 0) continue;

        final applied = remaining >= dueAmount ? dueAmount : remaining;
        if (applied <= 0) continue;

        final totalPrice = _parseDouble(data['total_price']);
        final newDue = (dueAmount - applied).clamp(0.0, totalPrice).toDouble();
        final isPaid = newDue <= 0;
        final now = Timestamp.now();
        final paymentEvents = _appendPaymentEvent(data, applied, now);

        remaining -= applied;

        transaction.update(liveSnap.reference, {
          'is_deferred': true,
          'paid': isPaid,
          'due_amount': newDue,
          if (isPaid) 'settled_at': FieldValue.serverTimestamp(),
          'last_payment_at': now,
          'last_payment_amount': applied,
          'payment_events': paymentEvents,
        });
      }
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchPaymentEventsForRange({required DateTimeRange range}) async {
    final snap = await _firestore
        .collection('sales')
        .where(
          'last_payment_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('last_payment_at', isLessThan: Timestamp.fromDate(range.end))
        .get();
    return snap.docs;
  }

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
          existing.add(entry.cast<String, dynamic>());
        }
      }
    }
    existing.add({'amount': amount, 'at': at});
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
