import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// يجلب مبيعات الشهر بالكامل (بداية 4ص محليًا → 4ص لليوم التالي) ثم يحول إلى UTC للاستعلام.
final salesRawForMonthProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>((
      ref,
      month,
    ) async {
      final y = month.year;
      final m = month.month;
      final dim = DateUtils.getDaysInMonth(y, m);

      // 4 الفجر محليًا ثم تحويل لـ UTC
      final startUtc = DateTime(y, m, 1, 4).toUtc();
      final endUtc = DateTime(
        y,
        m,
        dim,
        4,
      ).add(const Duration(days: 1)).toUtc();

      final q = FirebaseFirestore.instance
          .collection('sales')
          .where('created_at', isGreaterThanOrEqualTo: startUtc)
          .where('created_at', isLessThan: endUtc)
          .orderBy('created_at', descending: false);

      final snap = await q.get();

      return snap.docs.map((d) {
        final m = d.data();
        // لو حابب تحتفظ بالـid:
        m['id'] = d.id;
        return m;
      }).toList();
    });
