import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// U?U,O�O� U.O"USO1OO� OU,O'U�O� O"OU,U�OU.U, (O"O_OUSOc 4O� U.O-U,USU<O �+' 4O� U,U,USU^U. OU,O�OU,US) O�U. USO-U^U, O�U,U% UTC U,U,OO3O�O1U,OU..
final salesRawForMonthProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>((
      ref,
      month,
    ) async {
      final y = month.year;
      final m = month.month;
      final dim = DateUtils.getDaysInMonth(y, m);

      // 4 OU,U?O�O� U.O-U,USU<O O�U. O�O-U^USU, U,U? UTC
      final startUtc = DateTime(y, m, 1, 4).toUtc();
      final endUtc = DateTime(
        y,
        m,
        dim,
        4,
      ).add(const Duration(days: 1)).toUtc();

      final snap = await FirebaseFirestore.instance
          .collection('sales')
          .where('created_at', isGreaterThanOrEqualTo: startUtc)
          .where('created_at', isLessThan: endUtc)
          .orderBy('created_at', descending: false)
          .get();

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
        // U,U^ O-OO"O" O�O-O�U?O, O"OU,U?id:
        m['id'] = d.id;
        combined[d.id] = m;
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
