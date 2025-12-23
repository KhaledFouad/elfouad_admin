import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final salesRawForMonthProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>((
      ref,
      month,
    ) async {
      final y = month.year;
      final m = month.month;
      final dim = DateUtils.getDaysInMonth(y, m);

      final startUtc = DateTime(y, m, 1, 4).toUtc();
      final endUtc = DateTime(
        y,
        m,
        dim,
        4,
      ).add(const Duration(days: 1)).toUtc();
      final startIso = startUtc.toIso8601String();
      final endIso = endUtc.toIso8601String();
      final startMs = startUtc.millisecondsSinceEpoch;
      final endMs = endUtc.millisecondsSinceEpoch;

      final snap = await FirebaseFirestore.instance
          .collection('sales')
          .where('created_at', isGreaterThanOrEqualTo: startUtc)
          .where('created_at', isLessThan: endUtc)
          .orderBy('created_at', descending: false)
          .get();
      QuerySnapshot<Map<String, dynamic>>? snapStr;
      try {
        snapStr = await FirebaseFirestore.instance
            .collection('sales')
            .where('created_at', isGreaterThanOrEqualTo: startIso)
            .where('created_at', isLessThan: endIso)
            .orderBy('created_at', descending: false)
            .get();
      } catch (_) {
        snapStr = null;
      }
      QuerySnapshot<Map<String, dynamic>>? snapNum;
      try {
        snapNum = await FirebaseFirestore.instance
            .collection('sales')
            .where('created_at', isGreaterThanOrEqualTo: startMs)
            .where('created_at', isLessThan: endMs)
            .orderBy('created_at', descending: false)
            .get();
      } catch (_) {
        snapNum = null;
      }

      QuerySnapshot<Map<String, dynamic>>? snapOrig;
      try {
        snapOrig = await FirebaseFirestore.instance
            .collection('sales')
            .where('original_created_at', isGreaterThanOrEqualTo: startUtc)
            .where('original_created_at', isLessThan: endUtc)
            .orderBy('original_created_at', descending: false)
            .get();
      } catch (_) {
        snapOrig = null;
      }

      final combined = <String, Map<String, dynamic>>{};

      for (final d in snap.docs) {
        final m = d.data();
        m['id'] = d.id;
        combined[d.id] = m;
      }

      if (snapStr != null) {
        for (final d in snapStr.docs) {
          final m = d.data();
          m['id'] = d.id;
          combined[d.id] = m;
        }
      }
      if (snapNum != null) {
        for (final d in snapNum.docs) {
          final m = d.data();
          m['id'] = d.id;
          combined[d.id] = m;
        }
      }

      if (snapOrig != null) {
        for (final d in snapOrig.docs) {
          final m = d.data();
          m['id'] = d.id;
          combined[d.id] = m;
        }
      }

      return combined.values.toList();
    });
