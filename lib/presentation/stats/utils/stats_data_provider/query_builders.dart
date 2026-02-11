part of '../stats_data_provider.dart';

/// Firestore query builders and range filters for stats sources.
Future<QuerySnapshot<Map<String, dynamic>>> _getQuerySnapshot(
  Query<Map<String, dynamic>> query, {
  bool cacheFirst = false,
}) async {
  if (!cacheFirst) return query.get();
  try {
    final cached = await query.get(const GetOptions(source: Source.cache));
    if (cached.docs.isNotEmpty) return cached;
  } catch (_) {}
  return query.get();
}

const List<String> _salesCollections = ['sales', 'deferred_sales'];

Future<List<Map<String, dynamic>>> _fetchSalesRawForMonth(
  DateTime month, {
  bool cacheFirst = false,
}) async {
  final y = month.year;
  final m = month.month;
  final dim = DateUtils.getDaysInMonth(y, m);

  final startUtc = DateTime(y, m, 1, 4).toUtc();
  final endUtc = DateTime(y, m, dim, 4).add(const Duration(days: 1)).toUtc();
  final startIso = startUtc.toIso8601String();
  final endIso = endUtc.toIso8601String();
  final startMs = startUtc.millisecondsSinceEpoch;
  final endMs = endUtc.millisecondsSinceEpoch;
  final combined = <String, Map<String, dynamic>>{};
  final db = FirebaseFirestore.instance;

  void mergeDocs(QuerySnapshot<Map<String, dynamic>> snap, String collection) {
    for (final d in snap.docs) {
      final data = d.data();
      if (collection == 'deferred_sales' &&
          (data['is_deferred'] ?? false) != true) {
        data['is_deferred'] = true;
      }
      data['id'] = d.id;
      combined[d.id] = data;
    }
  }

  Future<void> mergeTimestampQueries(String collection) async {
    Future<void> mergeField(String field) async {
      try {
        final snap = await _getQuerySnapshot(
          db
              .collection(collection)
              .where(field, isGreaterThanOrEqualTo: startUtc)
              .where(field, isLessThan: endUtc)
              .orderBy(field, descending: false),
          cacheFirst: cacheFirst,
        );
        mergeDocs(snap, collection);
      } catch (_) {}
    }

    await mergeField('created_at');
    await mergeField('original_created_at');
    if (collection == 'deferred_sales') {
      await mergeField('settled_at');
      await mergeField('updated_at');
      await mergeField('last_payment_at');
    }
  }

  Future<void> mergeStringQueries(String collection) async {
    Future<void> mergeField(String field) async {
      try {
        final snap = await _getQuerySnapshot(
          db
              .collection(collection)
              .where(field, isGreaterThanOrEqualTo: startIso)
              .where(field, isLessThan: endIso)
              .orderBy(field, descending: false),
          cacheFirst: cacheFirst,
        );
        mergeDocs(snap, collection);
      } catch (_) {}
    }

    await mergeField('created_at');
    await mergeField('original_created_at');
    if (collection == 'deferred_sales') {
      await mergeField('settled_at');
      await mergeField('updated_at');
      await mergeField('last_payment_at');
    }
  }

  Future<void> mergeNumericQueries(String collection) async {
    Future<void> mergeField(String field) async {
      try {
        final snap = await _getQuerySnapshot(
          db
              .collection(collection)
              .where(field, isGreaterThanOrEqualTo: startMs)
              .where(field, isLessThan: endMs)
              .orderBy(field, descending: false),
          cacheFirst: cacheFirst,
        );
        mergeDocs(snap, collection);
      } catch (_) {}
    }

    await mergeField('created_at');
    await mergeField('original_created_at');
    if (collection == 'deferred_sales') {
      await mergeField('settled_at');
      await mergeField('updated_at');
      await mergeField('last_payment_at');
    }
  }

  for (final collection in _salesCollections) {
    await mergeTimestampQueries(collection);
  }

  if (combined.isNotEmpty) {
    return combined.values.toList();
  }

  for (final collection in _salesCollections) {
    await mergeStringQueries(collection);
  }

  if (combined.isNotEmpty) {
    return combined.values.toList();
  }

  for (final collection in _salesCollections) {
    await mergeNumericQueries(collection);
  }

  return combined.values.toList();
}

List<Map<String, dynamic>> _filterStatsSales(
  List<Map<String, dynamic>> rawMonth, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  return rawMonth.where((m) {
    final inProd = _inProductionRange(m, startUtc, endUtc);
    final inFin = _inFinancialRange(m, startUtc, endUtc);
    final deferredPaid = _deferredPaidAmountInRange(m, startUtc, endUtc);
    return inProd || inFin || deferredPaid > 0;
  }).toList();
}

Future<List<Map<String, dynamic>>> _fetchStatsExpenses({
  required DateTime startUtc,
  required DateTime endUtc,
  bool cacheFirst = false,
}) async {
  final snap = await _getQuerySnapshot(
    FirebaseFirestore.instance
        .collection('expenses')
        .where('created_at', isGreaterThanOrEqualTo: startUtc)
        .where('created_at', isLessThan: endUtc),
    cacheFirst: cacheFirst,
  );

  return snap.docs.map((d) => d.data()).toList();
}

List<Map<String, dynamic>> _filterStatsExpenses(
  List<Map<String, dynamic>> raw, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  return raw.where((m) {
    final ts = _asUtc(m['created_at'] ?? m['createdAt'] ?? m['date']);
    return _inRangeUtc(ts, startUtc, endUtc);
  }).toList();
}
