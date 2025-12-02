class DayBucket {
  DayBucket({
    required this.dayKey,
    required this.ids,
    required this.opCount,
    required this.sumPrice,
    required this.sumCost,
    required this.sumProfit,
    required this.cups,
    required this.grams,
    required this.extrasPieces,
  });

  final String dayKey;
  final List<String> ids;
  final int opCount;
  final double sumPrice;
  final double sumCost;
  final double sumProfit;
  final int cups;
  final double grams;
  final int extrasPieces;
}

String _opDayKeyFromLocal(DateTime local) {
  final s = local.subtract(const Duration(hours: 4));
  return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? 0}') ?? 0.0;
}

DateTime _parseIso(String? v) =>
    DateTime.tryParse(v ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);

DateTime _financialTime(
  DateTime created,
  DateTime settled,
  DateTime updated,
  bool isDeferred,
  bool paid,
) {
  if (paid) {
    if (settled.millisecondsSinceEpoch > 0) return settled;
    if (updated.millisecondsSinceEpoch > 0) return updated;
  }
  return created;
}

/// payload: {'rows': List<Map>, 'start': DateTime.toIso8601String, 'end': ...}
Future<List<DayBucket>> buildBuckets(Map payload) async {
  final rows = (payload['rows'] as List).cast<Map<String, dynamic>>();
  final start = DateTime.parse(payload['start'] as String);
  final end = DateTime.parse(payload['end'] as String);

  bool inRange(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  final Map<String, List<Map<String, dynamic>>> byDay = {};
  for (final m in rows) {
    final createdAt = _parseIso(m['created_at_iso'] as String?);
    final originalCreatedAt =
        _parseIso(m['original_created_at_iso'] as String?);
    final settledAt = _parseIso(m['settled_at_iso'] as String?);
    final updatedAt = _parseIso(m['updated_at_iso'] as String?);
    final isDeferred = m['is_deferred'] == true;
    final paid = m['paid'] == true || !isDeferred;
    final id = (m['id'] ?? '') as String;

    final productionTime =
        (originalCreatedAt.millisecondsSinceEpoch > 0)
            ? originalCreatedAt
            : createdAt;
    final financialTime = _financialTime(
      createdAt,
      settledAt,
      updatedAt,
      isDeferred,
      paid,
    );

    final productionInRange = inRange(productionTime);
    final financialInRange = inRange(financialTime);
    if (!productionInRange && !financialInRange) continue;

    if (productionInRange) {
      final key = _opDayKeyFromLocal(productionTime);
      final bucket = (byDay[key] ??= []);
      bucket.add({...m, '__phase': 'production', '__id': id});
    }
    if (financialInRange) {
      final key = _opDayKeyFromLocal(financialTime);
      final bucket = (byDay[key] ??= []);
      bucket.add({...m, '__phase': 'financial', '__id': id});
    }
  }

  final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  final out = <DayBucket>[];
  for (final k in keys) {
    final es = byDay[k]!;
    double price = 0, cost = 0, profit = 0, grams = 0;
    int cups = 0;
    int extrasPieces = 0;
    int opCount = 0;
    final ids = <String>{};

    for (final m in es) {
      final phase = (m['__phase'] ?? '') as String;
      final id = (m['__id'] ?? '') as String;
      final isProdPhase = phase == 'production';
      final isFinPhase = phase == 'financial';
      final isDeferred = m['is_deferred'] == true;
      final paid = m['paid'] == true || !isDeferred;

      if (isFinPhase && paid) {
        price += _d(m['total_price']);
        cost += _d(m['total_cost']);
        profit += _d(m['profit_total']);
        ids.add(id);
      }

      if (isProdPhase) opCount += 1;

      final type = (m['type'] ?? '').toString();
      if (isProdPhase) {
        if (type == 'drink') {
          final q = _d(m['quantity']);
          cups += (q > 0 ? q.round() : 1);
        } else if (type == 'single' || type == 'ready_blend') {
          grams += _d(m['grams']);
        } else if (type == 'custom_blend') {
          grams += _d(m['total_grams']);
        }

        final isExtra = type == 'extra' ||
            ((m['unit'] ?? '').toString() == 'piece' &&
                m.containsKey('extra_id'));
        if (isExtra) {
          final q = _d(m['quantity']);
          extrasPieces += (q > 0 ? q.round() : 1);
        }
      }
    }
    out.add(
      DayBucket(
        dayKey: k,
        ids: ids.toList(),
        opCount: opCount > ids.length ? opCount : ids.length,
        sumPrice: price,
        sumCost: cost,
        sumProfit: profit,
        cups: cups,
        grams: grams,
        extrasPieces: extrasPieces,
      ),
    );
  }
  return out;
}
