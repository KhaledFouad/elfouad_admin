import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// شيل أي import لـ legacy.dart من أي ملف—مش محتاجينه هنا.

// تبويب المخزون
enum InventoryTab { all, singles, blends, extras, drinks }

// تحويل آمن لأرقام
double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

// صف موحّد للأصناف المنفردة والتوليفات
class InventoryRow {
  final String id;
  final String name;
  final String variant; // درجة التحميص
  final double stockG; // جرامات
  final double minLevelG; // حد أدنى تحذيري
  final double sellPerKg; // سعر/كجم
  final double costPerKg; // تكلفة/كجم
  final String coll; // 'singles' | 'blends'
  final DocumentReference<Map<String, dynamic>> ref;

  const InventoryRow({
    required this.id,
    required this.name,
    required this.variant,
    required this.stockG,
    required this.minLevelG,
    required this.sellPerKg,
    required this.costPerKg,
    required this.coll,
    required this.ref,
  });

  bool get isSingle => coll == 'singles';
  bool get isBlend => coll == 'blends';
  bool get isExtra => false;
}

class ExtraInventoryRow {
  final String id;
  final String name;
  final String category;
  final bool active;
  final double priceSell;
  final double costUnit;
  final double stockUnits;
  final String unit;
  final DocumentReference<Map<String, dynamic>> ref;

  const ExtraInventoryRow({
    required this.id,
    required this.name,
    required this.category,
    required this.active,
    required this.priceSell,
    required this.costUnit,
    required this.stockUnits,
    required this.unit,
    required this.ref,
  });
}

double _stockGFrom(Map<String, dynamic> m) {
  // ترتيب التفضيل: stock ثم باقي الأسماء الشائعة
  final keys = [
    'stock',
    'stock_grams',
    'available_grams',
    'in_stock_grams',
    'grams_in_stock',
  ];
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v.replaceAll(',', '.'));
      if (p != null) return p;
    }
  }
  return 0.0;
}

InventoryRow _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? <String, dynamic>{};
  final sell = _d(
    m['sellPricePerKg'] ?? m['sellPerKg'] ?? m['sell_price_per_kg'],
  );
  final cost = _d(
    m['costPricePerKg'] ?? m['costPerKg'] ?? m['cost_price_per_kg'],
  );
  return InventoryRow(
    id: d.id,
    name: '${m['name'] ?? ''}',
    variant: '${m['variant'] ?? ''}',
    stockG: _stockGFrom(m), // ← هنا التعديل
    minLevelG: _d(m['minLevel']),
    sellPerKg: sell,
    costPerKg: cost,
    coll: d.reference.parent.id,
    ref: d.reference,
  );
}

double _extraNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9.,-]'), '');
      final parsed = double.tryParse(sanitized.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

String _extraString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

bool _extraBool(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
  }
  return true;
}

ExtraInventoryRow _extraFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data();
  return ExtraInventoryRow(
    id: d.id,
    name: _extraString(data, ['name', 'title', 'label']),
    category: _extraString(data, ['category', 'type', 'group']),
    active: _extraBool(data, ['active', 'isActive', 'enabled']),
    priceSell: _extraNumber(data, [
      'price_sell',
      'priceSell',
      'sellPrice',
      'sell_price',
      'price',
    ]),
    costUnit: _extraNumber(data, [
      'cost_unit',
      'costUnit',
      'costPrice',
      'cost',
      'purchase_price',
    ]),
    stockUnits: _extraNumber(data, [
      'stock_units',
      'stock',
      'quantity',
      'available',
      'inventory',
    ]),
    unit: _extraString(data, ['unit', 'unitName', 'unit_name']),
    ref: d.reference,
  );
}

// helper: sort محليًا (الاسم ثم التحميص)
List<InventoryRow> _sortByNameVariant(Iterable<InventoryRow> it) {
  final list = it.toList();
  list.sort((a, b) {
    final n = a.name.compareTo(b.name);
    if (n != 0) return n;
    return a.variant.compareTo(b.variant);
  });
  return list;
}

// Streams للأصناف المنفردة — (ترتيب من الذاكرة)
final singlesStreamProvider = StreamProvider<List<InventoryRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('singles')
      .orderBy('name')
      .snapshots()
      .map((s) => _sortByNameVariant(s.docs.map(_fromDoc)));
});

// Streams للتوليفات — (ترتيب من الذاكرة)
final blendsStreamProvider = StreamProvider<List<InventoryRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('blends')
      .orderBy('name')
      .snapshots()
      .map((s) => _sortByNameVariant(s.docs.map(_fromDoc)));
});

final extrasInventoryStreamProvider = StreamProvider<List<ExtraInventoryRow>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('extras')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(_extraFromDoc).toList());
});

// تبويب الصفحة الحالي
final inventoryTabProvider = StateProvider<InventoryTab>(
  (_) => InventoryTab.all,
);

List<InventoryRow> _safe(AsyncValue<List<InventoryRow>> a) =>
    a.maybeWhen(data: (v) => v, orElse: () => const <InventoryRow>[]);

// القائمة حسب التبويب (Blends أولًا في "الكل")
final inventoryListForTabProvider = Provider<List<InventoryRow>>((ref) {
  final tab = ref.watch(inventoryTabProvider);
  final singlesA = ref.watch(singlesStreamProvider);
  final blendsA = ref.watch(blendsStreamProvider);

  final singles = _safe(singlesA);
  final blends = _safe(blendsA);

  switch (tab) {
    case InventoryTab.singles:
      return singles;
    case InventoryTab.blends:
      return blends;
    case InventoryTab.extras:
      return const <InventoryRow>[];
    case InventoryTab.drinks:
      return const <InventoryRow>[]; // المشروبات خارج إدارة الجرامات
    case InventoryTab.all:
      return [...blends, ...singles]; // التوليفات أولًا
  }
});

// أكبر مخزون (للـ progress bar)
final inventoryMaxStockProvider = Provider<double>((ref) {
  final singles = _safe(ref.watch(singlesStreamProvider));
  final blends = _safe(ref.watch(blendsStreamProvider));
  double max = 0;
  for (final r in [...singles, ...blends]) {
    if (r.stockG > max) max = r.stockG;
  }
  return max <= 0 ? 1 : max;
});

// CRUD (تخصّص أصلي للـ singles/blends — السناكس عادة مش هنعدّلها من هنا)
Future<void> updateInventoryRow(
  InventoryRow r, {
  String? name,
  String? variant,
  double? stockG,
  double? sellPerKg,
  double? costPerKg,
  double? minLevelG,
}) async {
  final data = <String, dynamic>{};
  if (name != null) data['name'] = name;
  if (variant != null) data['variant'] = variant;

  if (stockG != null) {
    if (r.isExtra) {
      data['stock_units'] = stockG; // لو Extra نكتب في stock_units
    } else {
      data['stock'] = stockG; // وإلا نكتب في stock (جرامات)
    }
  }

  if (!r.isExtra) {
    if (sellPerKg != null) data['sellPricePerKg'] = sellPerKg;
    if (costPerKg != null) data['costPricePerKg'] = costPerKg;
    if (minLevelG != null) data['minLevel'] = minLevelG;
  } else {
    if (minLevelG != null) data['min_units'] = minLevelG; // حد أدنى للقطع
  }

  await r.ref.update(data);
}

Future<void> deleteInventoryRow(InventoryRow r) => r.ref.delete();

Future<void> createInventoryRow({
  required bool isBlend,
  required String name,
  String variant = '',
  required double stockG,
  required double sellPerKg,
  required double costPerKg,
  double minLevelG = 0,
}) async {
  final col = FirebaseFirestore.instance.collection(
    isBlend ? 'blends' : 'singles',
  );
  await col.add({
    'name': name,
    'variant': variant,
    'stock': stockG,
    'sellPricePerKg': sellPerKg,
    'costPricePerKg': costPerKg,
    'minLevel': minLevelG,
    'unit': 'g',
    'createdAt': DateTime.now().toUtc(),
  });
}
