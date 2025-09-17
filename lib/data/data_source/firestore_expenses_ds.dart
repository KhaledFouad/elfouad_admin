import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreExpensesDs {
  final FirebaseFirestore _db;
  FirestoreExpensesDs([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  Future<double> sumInRange(DateTime startUtc, DateTime endUtc) async {
    final q = await _db
        .collection('expenses')
        .where('created_at', isGreaterThanOrEqualTo: startUtc)
        .where('created_at', isLessThan: endUtc)
        .get();
    double s = 0;
    for (final d in q.docs) {
      final v = d.data()['amount'];
      s += (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;
    }
    return s;
  }
}
