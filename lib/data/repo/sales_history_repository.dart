import 'package:cloud_firestore/cloud_firestore.dart';
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

    const batchLimit = 400;
    var batch = _firestore.batch();
    var opCount = 0;
    for (final doc in combined.values) {
      batch.delete(doc.reference);
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

  Future<void> deleteSaleWithRollback(String saleId) async {
    final saleRef = _firestore.collection('sales').doc(saleId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(saleRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};

      final ops = _stockOpsFromSale(data);
      for (final entry in ops.entries) {
        final grams = entry.value;
        if (grams > 0) {
          transaction.update(entry.key, {'stock': FieldValue.increment(grams)});
        }
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

      transaction.delete(saleRef);
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

  bool _isCreditHidden(Map<String, dynamic> data) {
    return data['credit_hidden'] == true;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isExtraSale(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    if (type == 'extra') return true;
    return data.containsKey('extra_id') || data.containsKey('extra_name');
  }

  Map<DocumentReference<Map<String, dynamic>>, double> _stockOpsFromSale(
    Map<String, dynamic> data,
  ) {
    final out = <DocumentReference<Map<String, dynamic>>, double>{};

    void acc(String? coll, dynamic id, double grams) {
      if (coll == null || id == null || grams <= 0) return;
      final ref = _firestore.collection(coll).doc(id.toString());
      out[ref] = (out[ref] ?? 0.0) + grams;
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

    final type = (data['type'] ?? '').toString();
    if (type == 'single' || type == 'ready_blend') {
      final coll = type == 'single' ? 'singles' : 'blends';
      final id =
          data['single_id'] ??
          data['blend_id'] ??
          data['item_id'] ??
          data['id'];
      acc(coll, id, _parseDouble(data['grams']));
      return out;
    }

    if (type == 'custom_blend') {
      final rows = [
        ...asList(data['components']),
        ...asList(data['items']),
        ...asList(data['lines']),
      ];
      for (final row in rows) {
        final grams = _parseDouble(row['grams']);
        String? coll = (row['coll'] ?? row['collection'])?.toString();
        final id =
            row['id'] ?? row['item_id'] ?? row['single_id'] ?? row['blend_id'];
        coll ??= (row['blend_id'] != null)
            ? 'blends'
            : (row['single_id'] != null)
            ? 'singles'
            : null;
        acc(coll, id, grams);
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
