import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/expense.dart';

class FirestoreExpensesDs {
  final FirebaseFirestore _db;
  FirestoreExpensesDs([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  static const String _col = 'expenses';

  Expense _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final ts = m['created_at'] as Timestamp?;
    final createdUtc = (ts != null)
        ? ts.toDate().toUtc()
        : DateTime.tryParse('${m['created_at'] ?? ''}')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final amt = (m['amount'] is num)
        ? (m['amount'] as num).toDouble()
        : double.tryParse('${m['amount'] ?? 0}') ?? 0.0;

    return Expense(
      id: d.id,
      title: (m['title'] ?? '').toString(),
      amount: amt,
      createdAtUtc: createdUtc,
      notes: (m['notes'] ?? '').toString().isEmpty
          ? null
          : (m['notes'] ?? '').toString(),
      category: (m['category'] ?? '').toString().isEmpty
          ? null
          : (m['category'] ?? '').toString(),
    );
  }

  Map<String, dynamic> _toMap(Expense e) {
    return {
      'title': e.title,
      'amount': e.amount,
      'created_at': e.createdAtUtc,
      if (e.notes != null) 'notes': e.notes,
      if (e.category != null) 'category': e.category,
    };
  }

  Stream<List<Expense>> watchInRange(DateTime startUtc, DateTime endUtc) {
    return _db
        .collection(_col)
        .where('created_at', isGreaterThanOrEqualTo: startUtc)
        .where('created_at', isLessThan: endUtc)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Future<void> add(
    String title,
    double amount, {
    DateTime? whenUtc,
    String? notes,
    String? category,
  }) async {
    final nowUtc = whenUtc ?? DateTime.now().toUtc();
    await _db.collection(_col).add({
      'title': title,
      'amount': amount,
      'created_at': nowUtc,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (category != null && category.isNotEmpty) 'category': category,
    });
  }

  Future<void> update(Expense e) async {
    await _db
        .collection(_col)
        .doc(e.id)
        .set(_toMap(e), SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _db.collection(_col).doc(id).delete();
  }
}
