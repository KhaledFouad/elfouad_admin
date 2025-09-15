import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/sale.dart';

class SaleMapper {
  static Sale fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['created_at'];
    DateTime createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate().toUtc();
    } else if (ts is String) {
      createdAt = DateTime.parse(ts).toUtc();
    } else {
      createdAt = DateTime.now().toUtc();
    }
    return Sale(
      createdAt: createdAt,
      type: (d['type'] ?? 'drink') as String,
      name: (d['name'] ?? '') as String,
      variant: d['variant'] as String?,
      totalPrice: (d['total_price'] ?? 0).toDouble(),
      totalCost: (d['total_cost'] ?? 0).toDouble(),
      isComplimentary: (d['is_complimentary'] ?? false) as bool,
      quantity: (d['quantity'] == null) ? null : (d['quantity'] as num).toDouble(),
      drinkType: d['drink_type'] as String?,
      grams: (d['grams'] == null) ? null : (d['grams'] as num).toDouble(),
      totalGramsForCustom: (d['total_grams_for_custom'] == null) ? null : (d['total_grams_for_custom'] as num).toDouble(),
      blendFamily: d['blend_family'] as String?,
      singleOrigin: d['single_origin'] as String?,
    );
  }
}