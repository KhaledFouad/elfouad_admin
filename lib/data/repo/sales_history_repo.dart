import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/services/archive/archive_service.dart';
import 'package:flutter/material.dart';

part 'sales_history_queries.dart';
part 'sales_history_mapping.dart';

/// Single page payload used by sales-history pagination.
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

/// Repository public API for sales-history and credit flows.
class SalesHistoryRepository {
  SalesHistoryRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const int pageSize = 30;
  static const String _deferredCollection = 'deferred_sales';
  static const String _salesCollection = 'sales';

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCreatedInRange(
    DateTimeRange range, [
    int? limit,
  ]) {
    var query = _createdQuery(_salesCollection, range);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDeferredCreatedInRange(
    DateTimeRange range, [
    int? limit,
  ]) {
    var query = _createdQuery(_deferredCollection, range);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSettledInRange(
    DateTimeRange range, [
    int? limit,
  ]) {
    var query = _settledQuery(_salesCollection, range);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDeferredSettledInRange(
    DateTimeRange range, [
    int? limit,
  ]) {
    var query = _settledQuery(_deferredCollection, range);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPaymentInRange(
    DateTimeRange range, [
    int? limit,
  ]) {
    var query = _paymentQuery(_salesCollection, range);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDeferredPaymentInRange(
    DateTimeRange range, [
    int? limit,
  ]) {
    var query = _paymentQuery(_deferredCollection, range);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots();
  }

  // صفحة واحدة (للـ List مع "عرض المزيد")
  Future<SalesPageResult> fetchPage({
    required DateTimeRange range,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final baseQuery = _createdQuery(_salesCollection, range);

    var pagedQuery = baseQuery.limit(pageSize);
    if (startAfter != null) {
      pagedQuery = pagedQuery.startAfterDocument(startAfter);
    }

    final baseSnap = await pagedQuery.get();
    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in baseSnap.docs) {
      combined[d.id] = d;
    }

    // أول صفحة: ضيف معاها الفواتير المسددة داخل النطاق
    if (startAfter == null) {
      final settledSnap = await _settledQuery(_salesCollection, range).get();
      for (final d in settledSnap.docs) {
        combined[d.id] = d;
      }
    }

    // دمج العمليات المؤجلة من المجموعة المنفصلة
    final deferredSnap = await _createdQuery(_deferredCollection, range).get();
    for (final d in deferredSnap.docs) {
      combined[d.id] = d;
    }
    if (startAfter == null) {
      final deferredSettled = await _settledQuery(
        _deferredCollection,
        range,
      ).get();
      for (final d in deferredSettled.docs) {
        combined[d.id] = d;
      }
    }

    final docs = combined.values.toList()
      ..sort((a, b) => _effectiveAtOf(b).compareTo(_effectiveAtOf(a)));

    final hasMore = baseSnap.docs.length == pageSize;
    final lastDoc = baseSnap.docs.isNotEmpty ? baseSnap.docs.last : startAfter;

    return SalesPageResult(docs: docs, lastDoc: lastDoc, hasMore: hasMore);
  }

  /// استعلام بدون Limit — بنستعمله علشان نحسب إجمالي اليوم كله للـ Summary
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllForRange({
    required DateTimeRange range,
  }) async {
    final createdSnap = await _createdQuery(_salesCollection, range).get();
    final settledSnap = await _settledQuery(_salesCollection, range).get();
    final deferredCreated = await _createdQuery(
      _deferredCollection,
      range,
    ).get();
    final deferredSettled = await _settledQuery(
      _deferredCollection,
      range,
    ).get();

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in createdSnap.docs) {
      combined[d.id] = d;
    }
    for (final d in settledSnap.docs) {
      combined[d.id] = d;
    }
    for (final d in deferredCreated.docs) {
      combined[d.id] = d;
    }
    for (final d in deferredSettled.docs) {
      combined[d.id] = d;
    }

    return combined.values.toList();
  }

  Future<void> settleDeferredSale(String saleId) async {
    final deferredRef = _firestore.collection(_deferredCollection).doc(saleId);
    final salesRef = _firestore.collection(_salesCollection).doc(saleId);

    await _firestore.runTransaction((transaction) async {
      var snapshot = await transaction.get(deferredRef);
      var ref = deferredRef;
      if (!snapshot.exists) {
        snapshot = await transaction.get(salesRef);
        ref = salesRef;
      }
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
  fetchCreditSales() => _fetchCreditSales();

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchPaymentEventsForRange({required DateTimeRange range}) =>
      _fetchPaymentEventsForRange(range: range);

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
    final docs = await fetchCreditSales();
    var count = 0;
    for (final doc in docs) {
      final data = doc.data();
      if (_isCreditHidden(data)) continue;
      if (_isDeferredDoc(doc) && !_isPaidDoc(doc)) {
        count++;
      }
    }
    return count;
  }

  Stream<int> watchUnpaidCreditCount() {
    final controller = StreamController<int>.broadcast();

    Set<String> deferredIds = {};
    Set<String> salesDeferredIds = {};
    Set<String> salesCreditIds = {};

    Set<String> unpaidFromSnap(QuerySnapshot<Map<String, dynamic>> snap) {
      final out = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        if (_isCreditHidden(data)) continue;
        if (_isDeferredDoc(doc) && !_isPaidDoc(doc)) {
          out.add(doc.id);
        }
      }
      return out;
    }

    void emitCount() {
      final merged = <String>{
        ...deferredIds,
        ...salesDeferredIds,
        ...salesCreditIds,
      };
      if (!controller.isClosed) {
        controller.add(merged.length);
      }
    }

    final deferredSub = _firestore
        .collection(_deferredCollection)
        .snapshots()
        .listen((snap) {
          deferredIds = unpaidFromSnap(snap);
          emitCount();
        }, onError: controller.addError);

    final salesDeferredSub = _firestore
        .collection(_salesCollection)
        .where('is_deferred', isEqualTo: true)
        .snapshots()
        .listen((snap) {
          salesDeferredIds = unpaidFromSnap(snap);
          emitCount();
        }, onError: controller.addError);

    final salesCreditSub = _firestore
        .collection(_salesCollection)
        .where('is_credit', isEqualTo: true)
        .snapshots()
        .listen((snap) {
          salesCreditIds = unpaidFromSnap(snap);
          emitCount();
        }, onError: controller.addError);

    controller.onCancel = () async {
      await deferredSub.cancel();
      await salesDeferredSub.cancel();
      await salesCreditSub.cancel();
    };

    return controller.stream;
  }

  Future<void> hideCreditCustomer(String customerName) async {
    final name = customerName.trim();
    if (name.isEmpty) {
      throw Exception('Customer name is required.');
    }

    final targets = await _fetchCreditDocsByCustomer(name);
    if (targets.isEmpty) return;

    await _batchUpdateDocs(targets, {
      'credit_hidden': true,
      'credit_hidden_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renameCreditCustomer({
    required String oldName,
    required String newName,
  }) async {
    final from = oldName.trim();
    final to = newName.trim();
    if (from.isEmpty || to.isEmpty) {
      throw Exception('Customer name is required.');
    }
    if (from == to) return;

    final targets = await _fetchCreditDocsByCustomer(from);
    if (targets.isEmpty) return;

    await _batchUpdateDocs(targets, {'note': to});
  }

  Future<void> deleteCreditCustomer(String customerName) async {
    final name = customerName.trim();
    if (name.isEmpty) {
      throw Exception('Customer name is required.');
    }

    final targets = await _fetchCreditDocsByCustomer(name);
    if (targets.isEmpty) return;

    for (final doc in targets) {
      await archiveThenDelete(
        srcRef: doc.reference,
        kind: 'sale',
        reason: 'credit_customer_delete',
      );
    }
  }

  Future<void> deleteSaleWithRollback(String saleId) async {
    final salesRef = _firestore.collection('sales').doc(saleId);
    final deferredRef = _firestore.collection(_deferredCollection).doc(saleId);

    await _firestore.runTransaction((transaction) async {
      var saleRef = salesRef;
      var snap = await transaction.get(saleRef);
      if (!snap.exists) {
        saleRef = deferredRef;
        snap = await transaction.get(saleRef);
      }
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
      final drinkItemOps = await _drinkOpsFromLineItems(
        transaction,
        _lineItemsFromSale(data),
      );
      if (drinkItemOps.isNotEmpty) {
        _mergeOps(ops, drinkItemOps);
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

      final archiveRef = _firestore.collection(archiveBinCollection).doc();
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
      final drinkItemOps = await _drinkOpsFromLineItems(
        transaction,
        _lineItemsFromSale(saleData),
      );
      if (drinkItemOps.isNotEmpty) {
        _mergeOps(ops, drinkItemOps);
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

    final targets = await _fetchCreditDocsByCustomer(name);
    if (targets.isEmpty) {
      return;
    }

    final docs = targets.where((doc) {
      return _isDeferredDoc(doc) && !_isPaidDoc(doc);
    }).toList()..sort((a, b) => _createdAtOf(a).compareTo(_createdAtOf(b)));

    if (docs.isEmpty) {
      return;
    }

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
        if (!_isDeferredWithRef(data, liveSnap.reference) ||
            _isPaidWithRef(data, liveSnap.reference)) {
          continue;
        }
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

  Future<void> updateCreditPaymentEvent({
    required String saleId,
    String? eventId,
    int? eventIndex,
    required DateTime eventAt,
    required double oldAmount,
    required double newAmount,
  }) async {
    if (saleId.trim().isEmpty) {
      throw Exception('Sale id is required.');
    }
    if (!newAmount.isFinite || newAmount <= 0) {
      throw Exception('Invalid updated payment amount.');
    }
    await _mutateCreditPaymentEvent(
      saleId: saleId,
      eventId: eventId,
      eventIndex: eventIndex,
      eventAt: eventAt,
      amount: oldAmount,
      updatedAmount: newAmount,
      deleteEvent: false,
    );
  }

  Future<void> deleteCreditPaymentEvent({
    required String saleId,
    String? eventId,
    int? eventIndex,
    required DateTime eventAt,
    required double amount,
  }) async {
    if (saleId.trim().isEmpty) {
      throw Exception('Sale id is required.');
    }
    await _mutateCreditPaymentEvent(
      saleId: saleId,
      eventId: eventId,
      eventIndex: eventIndex,
      eventAt: eventAt,
      amount: amount,
      updatedAmount: null,
      deleteEvent: true,
    );
  }
}
