import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class InventoryRow {
  final String id;
  final String name;
  final String variant; // درجة التحميص
  final double stockG;
  final double minLevelG;
  final double sellPerKg;
  final String image;
  final String collection; // 'singles' | 'blends'
  const InventoryRow({
    required this.id,
    required this.name,
    required this.variant,
    required this.stockG,
    required this.minLevelG,
    required this.sellPerKg,
    required this.image,
    required this.collection,
  });
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

InventoryRow _mapDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> d,
  String col,
) {
  final m = d.data();
  return InventoryRow(
    id: d.id,
    name: (m['name'] ?? '').toString(),
    variant: (m['variant'] ?? '').toString(),
    stockG: _d(m['stock']),
    minLevelG: _d(m['minLevel']),
    sellPerKg: _d(m['sellPricePerKg']),
    image: (m['image'] ?? '').toString(),
    collection: col,
  );
}

/// ⚠️ شِلّنا orderBy('variant') علشان نتجنّب الـ composite index
final singlesStreamProvider = StreamProvider<List<InventoryRow>>((ref) async* {
  final q = FirebaseFirestore.instance.collection('singles').orderBy('name');
  yield* q.snapshots().map((s) {
    final rows = s.docs.map((d) => _mapDoc(d, 'singles')).toList();
    rows.sort((a, b) {
      final c = a.name.compareTo(b.name);
      return c != 0 ? c : a.variant.compareTo(b.variant);
    });
    return rows;
  });
});

final blendsStreamProvider = StreamProvider<List<InventoryRow>>((ref) async* {
  final q = FirebaseFirestore.instance.collection('blends').orderBy('name');
  yield* q.snapshots().map((s) {
    final rows = s.docs.map((d) => _mapDoc(d, 'blends')).toList();
    rows.sort((a, b) {
      final c = a.name.compareTo(b.name);
      return c != 0 ? c : a.variant.compareTo(b.variant);
    });
    return rows;
  });
});

/// أقصى مخزون لاستخدامه في progress bar
final inventoryMaxStockProvider = Provider<double>((ref) {
  double max = 0;
  final singles =
      ref.watch(singlesStreamProvider).asData?.value ?? const <InventoryRow>[];
  final blends =
      ref.watch(blendsStreamProvider).asData?.value ?? const <InventoryRow>[];
  for (final r in [...singles, ...blends]) {
    if (r.stockG > max) max = r.stockG;
  }
  return max <= 0 ? 1 : max;
});

/// تبويب المخزون
enum InventoryTab { all, drinks, singles, blends }

final inventoryTabProvider = StateProvider<InventoryTab>(
  (ref) => InventoryTab.all,
);

/// دمج للعرض حسب التبويب (الكل → التوليفات أولًا)
final inventoryListForTabProvider = Provider<List<InventoryRow>>((ref) {
  final tab = ref.watch(inventoryTabProvider);
  final singles =
      ref.watch(singlesStreamProvider).asData?.value ?? const <InventoryRow>[];
  final blends =
      ref.watch(blendsStreamProvider).asData?.value ?? const <InventoryRow>[];

  switch (tab) {
    case InventoryTab.singles:
      return singles;
    case InventoryTab.blends:
      return blends;
    case InventoryTab.drinks:
      return const <InventoryRow>[]; // المخزون لا يحتوي مشروبات
    case InventoryTab.all:
      return [...blends, ...singles]; // ✅ التوليفات أولًا
  }
});

Future<void> updateInventoryRow(
  InventoryRow r, {
  String? name,
  String? variant,
  double? stockG,
  double? sellPerKg,
  double? minLevelG,
}) {
  final ref = FirebaseFirestore.instance.collection(r.collection).doc(r.id);
  final upd = <String, dynamic>{
    if (name != null) 'name': name,
    if (variant != null) 'variant': variant,
    if (stockG != null) 'stock': stockG,
    if (sellPerKg != null) 'sellPricePerKg': sellPerKg,
    if (minLevelG != null) 'minLevel': minLevelG,
  };
  return ref.update(upd);
}

Future<void> deleteInventoryRow(InventoryRow r) =>
    FirebaseFirestore.instance.collection(r.collection).doc(r.id).delete();
