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
    } else if (ts is num) {
      final raw = ts.toInt();
      final ms = raw < 10000000000 ? raw * 1000 : raw;
      createdAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } else {
      createdAt = DateTime.now().toUtc();
    }
    double toDoubleValue(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;
    return Sale(
      createdAt: createdAt,
      type: (d['type'] ?? 'drink').toString(),
      name: (d['name'] ?? '').toString(),
      drinkName: (d['drink_name'] ?? '').toString(),
      variant: d['variant']?.toString(),
      totalPrice: toDoubleValue(d['total_price']),
      totalCost: toDoubleValue(d['total_cost']),
      isComplimentary: (d['is_complimentary'] ?? false) == true,
      isSpiced: (d['is_spiced'] ?? false) == true,
      quantity: d['quantity'] == null ? null : toDoubleValue(d['quantity']),
      drinkType: d['drink_type']?.toString(),
      grams: d['grams'] == null ? null : toDoubleValue(d['grams']),
      totalGramsForCustom: d['total_grams_for_custom'] != null
          ? toDoubleValue(d['total_grams_for_custom'])
          : (d['total_grams'] == null ? null : toDoubleValue(d['total_grams'])),
      blendFamily: d['blend_family']?.toString(),
      singleOrigin: d['single_origin']?.toString(),
    );
  }
}
