import 'package:cloud_firestore/cloud_firestore.dart';

double spiceRatePerKgForSingle(String name) {
  final n = name.trim();
  if (n.contains('كولوم') || n.contains('كولومبي')) return 80.0;
  if (n.contains('برازي') || n.contains('برازيلي')) return 60.0;
  if (n.contains('حبش') || n.contains('حبشي')) return 60.0;
  if (n.contains('هند') || n.contains('هندي')) return 60.0;
  return 40.0;
}

Future<({double pricePerKg, double costPerKg})> fetchSpiceRatesForSale(
  Map<String, dynamic> sale,
) async {
  final db = FirebaseFirestore.instance;
  double price = 0.0;
  double cost = 0.0;

  final type = '${sale['type'] ?? ''}';
  String? coll;
  String? id =
      sale['product_id']?.toString() ??
      sale['productId']?.toString() ??
      sale['single_id']?.toString() ??
      sale['singleId']?.toString() ??
      sale['blend_id']?.toString() ??
      sale['blendId']?.toString() ??
      sale['item_id']?.toString() ??
      sale['itemId']?.toString() ??
      sale['id']?.toString();

  if (type == 'single' ||
      sale.containsKey('single_id') ||
      sale.containsKey('singleId') ||
      sale['lines_type'] == 'single') {
    coll = 'singles';
  } else if (type == 'ready_blend' ||
      sale.containsKey('blend_id') ||
      sale.containsKey('blendId') ||
      sale['lines_type'] == 'ready_blend') {
    coll = 'blends';
  }

  if (coll != null && id != null) {
    try {
      final doc = await db.collection(coll).doc(id).get();
      final m = doc.data();
      if (m != null) {
        price = _numOf(m['spicePricePerKg'] ?? m['spice_price_per_kg']);
        cost = _numOf(m['spiceCostPerKg'] ?? m['spice_cost_per_kg']);
      }
    } catch (_) {}
  }

  if (price <= 0 || cost <= 0) {
    try {
      final s = await db.collection('settings').doc('spice').get();
      final m = s.data();
      if (m != null) {
        if (price <= 0) price = _numOf(m['price_per_kg']);
        if (cost <= 0) cost = _numOf(m['cost_per_kg']);
      }
    } catch (_) {}
  }

  if (price <= 0) {
    final name =
        (sale['name'] ??
                sale['single_name'] ??
                sale['blend_name'] ??
                sale['product_name'] ??
                '')
            .toString();
    price = spiceRatePerKgForSingle(name);
  }

  if (cost <= 0 && price > 0) cost = (price * 0.5);

  return (pricePerKg: price, costPerKg: cost);
}

Future<({double pricePerKg, double costPerKg})> fetchGinsengRatesForSale(
  Map<String, dynamic> sale,
) async {
  final db = FirebaseFirestore.instance;
  double price = _numOf(
    sale['ginseng_rate_per_kg'] ??
        sale['ginsengPricePerKg'] ??
        sale['ginseng_price_per_kg'],
  );
  double cost = _numOf(
    sale['ginseng_cost_per_kg'] ??
        sale['ginsengCostPerKg'] ??
        sale['ginseng_cost_per_kg'],
  );

  final type = '${sale['type'] ?? ''}';
  String? coll;
  String? id =
      sale['product_id']?.toString() ??
      sale['productId']?.toString() ??
      sale['single_id']?.toString() ??
      sale['singleId']?.toString() ??
      sale['blend_id']?.toString() ??
      sale['blendId']?.toString() ??
      sale['item_id']?.toString() ??
      sale['itemId']?.toString() ??
      sale['id']?.toString();

  if (type == 'single' ||
      sale.containsKey('single_id') ||
      sale.containsKey('singleId') ||
      sale['lines_type'] == 'single') {
    coll = 'singles';
  } else if (type == 'ready_blend' ||
      sale.containsKey('blend_id') ||
      sale.containsKey('blendId') ||
      sale['lines_type'] == 'ready_blend') {
    coll = 'blends';
  }

  if ((price <= 0 || cost <= 0) && coll != null && id != null) {
    try {
      final doc = await db.collection(coll).doc(id).get();
      final m = doc.data();
      if (m != null) {
        if (price <= 0) {
          price = _numOf(m['ginsengPricePerKg'] ?? m['ginseng_price_per_kg']);
        }
        if (cost <= 0) {
          cost = _numOf(m['ginsengCostPerKg'] ?? m['ginseng_cost_per_kg']);
        }
      }
    } catch (_) {}
  }

  if (price < 0) price = 0.0;
  if (cost < 0) cost = 0.0;

  return (pricePerKg: price, costPerKg: cost);
}

double _numOf(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}
