// history_compute.dart (ملف مساعد جديد)
import 'package:flutter/foundation.dart'; // compute
import 'package:cloud_firestore/cloud_firestore.dart';

class DayBucket {
  DayBucket({
    required this.dayKey,
    required this.ids,
    required this.sumPrice,
    required this.sumCost,
    required this.sumProfit,
    required this.cups,
    required this.grams,
  });

  final String dayKey;
  final List<String> ids;
  final double sumPrice;
  final double sumCost;
  final double sumProfit;
  final int cups;
  final double grams;
}

String _opDayKeyFromLocal(DateTime local) {
  final s = local.subtract(const Duration(hours: 4));
  return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? 0}') ?? 0.0;
}

/// payload: {'rows': List<Map>, 'start': DateTime.toIso8601String, 'end': ...}
Future<List<DayBucket>> buildBuckets(Map payload) async {
  final rows = (payload['rows'] as List).cast<Map<String, dynamic>>();
  final start = DateTime.parse(payload['start'] as String);
  final end = DateTime.parse(payload['end'] as String);

  bool inRange(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  final Map<String, List<Map<String, dynamic>>> byDay = {};
  for (final m in rows) {
    // “effective” time (الترحيل/التسوية)
    final createdAt = DateTime.tryParse(m['created_at_iso'] as String)!;
    final settledAtIso = m['settled_at_iso'] as String?;
    final settledAt = settledAtIso == null
        ? null
        : DateTime.tryParse(settledAtIso);
    final isDeferred = m['is_deferred'] == true;
    final paid = m['paid'] == true || !isDeferred;

    final DateTime effectiveTime = (isDeferred && !paid)
        ? DateTime.now().copyWith(
            hour: 5,
            minute: 0,
            second: 0,
            millisecond: 0,
            microsecond: 0,
          )
        : (paid && settledAt != null ? settledAt : createdAt);

    if (!(inRange(createdAt) ||
        (isDeferred && !paid) ||
        (paid && settledAt != null && inRange(settledAt!)))) {
      continue;
    }

    final key = _opDayKeyFromLocal(effectiveTime);
    (byDay[key] ??= []).add(m);
  }

  final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  final out = <DayBucket>[];
  for (final k in keys) {
    final es = byDay[k]!;
    double price = 0, cost = 0, profit = 0, grams = 0;
    int cups = 0;
    final ids = <String>[];

    for (final m in es) {
      final isDeferred = m['is_deferred'] == true;
      final paid = m['paid'] == true || !isDeferred;
      if (!(paid)) {
        // استبعد الأجل غير المدفوع من المجاميع
        // (لسه ظاهر في اليوم الحالي كقائمة فقط)
      } else {
        price += _d(m['total_price']);
        cost += _d(m['total_cost']);
        profit += _d(m['profit_total']);
      }
      final type = (m['type'] ?? '').toString();
      if (type == 'drink') {
        final q = _d(m['quantity']);
        cups += (q > 0 ? q.round() : 1);
      } else if (type == 'single' || type == 'ready_blend') {
        grams += _d(m['grams']);
      } else if (type == 'custom_blend') {
        grams += _d(m['total_grams']);
      }
      ids.add(m['id'] as String);
    }
    out.add(
      DayBucket(
        dayKey: k,
        ids: ids,
        sumPrice: price,
        sumCost: cost,
        sumProfit: profit,
        cups: cups,
        grams: grams,
      ),
    );
  }
  return out;
}
