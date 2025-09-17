import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';

class ProductMapper {
  static Product fromMap(String id, Map<String, dynamic> d, String collection) {
    double toDoubleValue(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;
    final type = collection == 'singles'
        ? 'single'
        : collection == 'blends'
        ? 'ready_blend'
        : 'drink';
    return Product(
      id: id,
      type: type,
      name: (d['name'] ?? '').toString(),
      roast: d['roast']?.toString(),
      family: d['family']?.toString(),
      pricePerKg: (type != 'drink')
          ? (d['price_per_kg'] == null
                ? null
                : toDoubleValue(d['price_per_kg']))
          : null,
      costPerKg: (type != 'drink')
          ? (d['cost_per_kg'] == null ? null : toDoubleValue(d['cost_per_kg']))
          : null,
      pricePerCup: (type == 'drink')
          ? (d['price_per_cup'] == null
                ? null
                : toDoubleValue(d['price_per_cup']))
          : null,
      costPerCup: (type == 'drink')
          ? (d['cost_per_cup'] == null
                ? null
                : toDoubleValue(d['cost_per_cup']))
          : null,
      stockGrams: toDoubleValue(d['stock_grams'] ?? 0),
      stockCups: (type == 'drink')
          ? (d['stock_cups'] == null ? null : toDoubleValue(d['stock_cups']))
          : null,
    );
  }

  static Map<String, dynamic> toMap(Product p) {
    final map = <String, dynamic>{
      'name': p.name,
      if (p.roast != null) 'roast': p.roast,
      if (p.family != null) 'family': p.family,
      'stock_grams': p.stockGrams,
    };
    if (p.type == 'drink') {
      if (p.pricePerCup != null) map['price_per_cup'] = p.pricePerCup;
      if (p.costPerCup != null) map['cost_per_cup'] = p.costPerCup;
      if (p.stockCups != null) map['stock_cups'] = p.stockCups;
    } else {
      if (p.pricePerKg != null) map['price_per_kg'] = p.pricePerKg;
      if (p.costPerKg != null) map['cost_per_kg'] = p.costPerKg;
    }
    return map;
  }

  // Legacy convenience
  static Product fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final col = doc.reference.parent.id; // 'drinks' | 'singles' | 'blends'
    return ProductMapper.fromMap(doc.id, doc.data(), col);
  }
}
