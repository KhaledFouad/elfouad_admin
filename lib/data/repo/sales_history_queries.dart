part of 'sales_history_repo.dart';

/// Query and mutation helpers that interact directly with Firestore.
extension _SalesHistoryQueries on SalesHistoryRepository {
  Query<Map<String, dynamic>> _createdQuery(
    String collection,
    DateTimeRange range,
  ) {
    return _firestore
        .collection(collection)
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('created_at', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('created_at', descending: true);
  }

  Query<Map<String, dynamic>> _settledQuery(
    String collection,
    DateTimeRange range,
  ) {
    return _firestore
        .collection(collection)
        .where(
          'settled_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('settled_at', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('settled_at', descending: true);
  }

  Query<Map<String, dynamic>> _paymentQuery(
    String collection,
    DateTimeRange range,
  ) {
    return _firestore
        .collection(collection)
        .where(
          'last_payment_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('last_payment_at', isLessThan: Timestamp.fromDate(range.end));
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchCreditSales() async {
    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    final deferredSnap = await _firestore
        .collection(SalesHistoryRepository._deferredCollection)
        .get();
    for (final doc in deferredSnap.docs) {
      final data = doc.data();
      if (_isCreditHidden(data)) continue;
      combined[doc.id] = doc;
    }

    final salesDeferred = await _firestore
        .collection(SalesHistoryRepository._salesCollection)
        .where('is_deferred', isEqualTo: true)
        .get();
    for (final doc in salesDeferred.docs) {
      final data = doc.data();
      if (_isCreditHidden(data)) continue;
      combined.putIfAbsent(doc.id, () => doc);
    }

    final salesCredit = await _firestore
        .collection(SalesHistoryRepository._salesCollection)
        .where('is_credit', isEqualTo: true)
        .get();
    for (final doc in salesCredit.docs) {
      final data = doc.data();
      if (_isCreditHidden(data)) continue;
      combined.putIfAbsent(doc.id, () => doc);
    }

    return combined.values.toList();
  }

  Future<void> _mutateCreditPaymentEvent({
    required String saleId,
    String? eventId,
    int? eventIndex,
    required DateTime eventAt,
    required double amount,
    required double? updatedAmount,
    required bool deleteEvent,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final target = await _findCreditSaleForUpdate(transaction, saleId.trim());
      final data = target.data;
      if (!_isDeferredWithRef(data, target.ref)) {
        throw Exception('Not a deferred sale.');
      }

      final totalPrice = _parseDouble(data['total_price']);
      if (totalPrice <= 0) {
        throw Exception('Deferred sale total is invalid.');
      }

      final events = _extractMutablePaymentEvents(data);
      if (events.isEmpty) {
        throw Exception('No payment events to mutate.');
      }

      final targetIndex = _locatePaymentEventIndex(
        events,
        eventId: eventId,
        eventIndex: eventIndex,
        eventAt: eventAt,
        amount: amount,
      );
      if (targetIndex < 0 || targetIndex >= events.length) {
        throw Exception('Payment event not found.');
      }

      if (deleteEvent) {
        events.removeAt(targetIndex);
      } else {
        final nextAmount = updatedAmount ?? 0;
        if (!nextAmount.isFinite || nextAmount <= 0) {
          throw Exception('Invalid updated payment amount.');
        }
        events[targetIndex] = events[targetIndex].copyWith(amount: nextAmount);
      }

      final normalizedEvents = _normalizedPaymentEvents(events);
      final update = _buildPaymentMutationUpdate(
        normalizedEvents,
        totalPrice: totalPrice,
      );
      transaction.update(target.ref, update);
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchPaymentEventsForRange({required DateTimeRange range}) async {
    final docs = await _fetchCreditSales();
    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    bool inRange(DateTime value) =>
        !value.isBefore(range.start) && value.isBefore(range.end);

    DateTime? asDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is num) {
        final raw = value.toInt();
        final ms = raw < 10000000000 ? raw * 1000 : raw;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      }
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    bool hasPaymentInRange(Map<String, dynamic> data) {
      final rawEvents = data['payment_events'];
      if (rawEvents is List && rawEvents.isNotEmpty) {
        for (final raw in rawEvents) {
          if (raw is! Map) continue;
          final event = raw.cast<String, dynamic>();
          final amount = _parseDouble(event['amount']);
          if (amount <= 0) continue;
          final at = asDate(event['at'] ?? event['paid_at'] ?? event['created_at']);
          if (at != null && inRange(at)) {
            return true;
          }
        }
      }

      final lastAmount = _parseDouble(data['last_payment_amount']);
      if (lastAmount <= 0) return false;
      final lastAt = asDate(data['last_payment_at']);
      return lastAt != null && inRange(lastAt);
    }

    for (final doc in docs) {
      final data = doc.data();
      if (!hasPaymentInRange(data)) continue;
      out.add(doc);
    }

    return out;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchCreditDocsByCustomer(String name) async {
    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    final deferredSnap = await _firestore
        .collection(SalesHistoryRepository._deferredCollection)
        .where('note', isEqualTo: name)
        .get();
    for (final doc in deferredSnap.docs) {
      final data = doc.data();
      if (_isCreditHidden(data)) continue;
      combined[doc.id] = doc;
    }

    final salesSnap = await _firestore
        .collection(SalesHistoryRepository._salesCollection)
        .where('note', isEqualTo: name)
        .get();
    for (final doc in salesSnap.docs) {
      final data = doc.data();
      if (_isCreditHidden(data)) continue;
      if (!_isDeferred(data)) continue;
      combined.putIfAbsent(doc.id, () => doc);
    }

    return combined.values.toList();
  }

  Future<void> _batchUpdateDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, dynamic> updates,
  ) async {
    if (docs.isEmpty) return;
    const batchLimit = 400;
    var batch = _firestore.batch();
    var opCount = 0;
    for (final doc in docs) {
      batch.update(doc.reference, updates);
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

  Future<_CreditSaleDoc> _findCreditSaleForUpdate(
    Transaction transaction,
    String saleId,
  ) async {
    final deferredRef = _firestore
        .collection(SalesHistoryRepository._deferredCollection)
        .doc(saleId);
    final salesRef = _firestore
        .collection(SalesHistoryRepository._salesCollection)
        .doc(saleId);

    var snapshot = await transaction.get(deferredRef);
    var ref = deferredRef;
    if (!snapshot.exists) {
      snapshot = await transaction.get(salesRef);
      ref = salesRef;
    }
    if (!snapshot.exists) {
      throw Exception('Sale not found.');
    }
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Sale data is missing.');
    }
    return _CreditSaleDoc(ref: ref, data: data);
  }
}
