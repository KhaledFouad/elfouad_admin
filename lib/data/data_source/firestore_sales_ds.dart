import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/sale.dart';
import '../mappers/sale_mapper.dart';

class FirestoreSalesDs {
  final FirebaseFirestore _db;
  FirestoreSalesDs([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  Future<List<Sale>> fetchRaw(DateTime startUtc, DateTime endUtc) async {
    final combined =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final coll in const ['sales', 'deferred_sales']) {
      final q = await _db
          .collection(coll)
          .where('created_at', isGreaterThanOrEqualTo: startUtc)
          .where('created_at', isLessThan: endUtc)
          .orderBy('created_at')
          .get();
      for (final doc in q.docs) {
        combined[doc.id] = doc;
      }
    }
    return combined.values.map(SaleMapper.fromDoc).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRange(
    DateTime startUtc,
    DateTime endUtc,
  ) {
    return _db
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: startUtc)
        .where('created_at', isLessThan: endUtc)
        .orderBy('created_at', descending: true)
        .snapshots();
  }
}
