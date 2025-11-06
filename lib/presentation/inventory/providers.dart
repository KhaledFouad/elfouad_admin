import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// تبويب المخزون
enum InventoryTab { all, singles, blends, extras, drinks }

// تحويل آمن لأرقام
double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

// صف موحّد للأصناف
class InventoryRow {
  final String id;
  final String name;
  final String variant; // درجة التحميص/الاختيار
  final double stockG; // جرامات أو "قطع" للسناكس
  final double minLevelG; // حد أدنى تحذيري (للجرامات أو قطع)
  final double sellPerKg; // سعر/كجم (أو 0 للسناكس)
  final double costPerKg; // تكلفة/كجم (أو 0 للسناكس)
  final String coll; // 'singles' | 'blends' | 'extras'
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
  bool get isExtra => coll == 'extras';
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
    stockG: _stockGFrom(m),
    minLevelG: _d(m['minLevel']),
    sellPerKg: sell,
    costPerKg: cost,
    coll: d.reference.parent.id,
    ref: d.reference,
  );
}

// تحويل خاص بالسناكس (stock_units → stockG)
InventoryRow _fromExtraDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? <String, dynamic>{};
  final units = (m['stock_units'] is num)
      ? (m['stock_units'] as num).toDouble()
      : _d(m['stock_units']);
  return InventoryRow(
    id: d.id,
    name: '${m['name'] ?? ''}',
    variant: '${m['variant'] ?? ''}',
    stockG: units, // ← هنا بنخزن "القطع" كـ stockG
    minLevelG: _d(m['min_units'] ?? m['minLevel']),
    sellPerKg: 0.0, // مش مستخدم للسناكس
    costPerKg: 0.0, // مش مستخدم للسناكس
    coll: d.reference.parent.id, // 'extras'
    ref: d.reference,
  );
}

// helper: sort محليًا (الاسم ثم التحميص/الاختيار)
List<InventoryRow> _sortByNameVariant(Iterable<InventoryRow> it) {
  final list = it.toList();
  list.sort((a, b) {
    final n = a.name.compareTo(b.name);
    if (n != 0) return n;
    return a.variant.compareTo(b.variant);
  });
  return list;
}

// Streams للأصناف المنفردة
final singlesStreamProvider = StreamProvider<List<InventoryRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('singles')
      .orderBy('name')
      .snapshots()
      .map((s) => _sortByNameVariant(s.docs.map(_fromDoc)));
});

// Streams للتوليفات
final blendsStreamProvider = StreamProvider<List<InventoryRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('blends')
      .orderBy('name')
      .snapshots()
      .map((s) => _sortByNameVariant(s.docs.map(_fromDoc)));
});

// Streams للسناكس (معمول/تمر)

// تبويب الصفحة الحالي
final inventoryTabProvider = StateProvider<InventoryTab>(
  (_) => InventoryTab.all,
);

List<InventoryRow> _safe(AsyncValue<List<InventoryRow>> a) =>
    a.maybeWhen(data: (v) => v, orElse: () => const <InventoryRow>[]);

// القائمة حسب التبويب (Blends أولًا في "الكل")
final inventoryListForTabProvider = Provider<List<InventoryRow>>((ref) {
  final tab = ref.watch(inventoryTabProvider);
  final singles = _safe(ref.watch(singlesStreamProvider));
  final blends = _safe(ref.watch(blendsStreamProvider));

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

// أكبر مخزون بناءً على "القائمة المعروضة حاليًا" (عشان progress يبقى مضبوط)
final inventoryMaxStockProvider = Provider<double>((ref) {
  final list = ref.watch(inventoryListForTabProvider);
  double max = 0;
  for (final r in list) {
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
