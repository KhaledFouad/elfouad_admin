import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

class InventoryRow {
  final String id;
  final String name;
  final String variant;
  final double stockG;
  final String coll; // 'singles' or 'blends'
  final DocumentReference<Map<String, dynamic>> ref;
  const InventoryRow({
    required this.id,
    required this.name,
    required this.variant,
    required this.stockG,
    required this.coll,
    required this.ref,
  });

  bool get isBlend => coll == 'blends';
}

InventoryRow _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? {};
  return InventoryRow(
    id: d.id,
    name: '${m['name'] ?? ''}',
    variant: '${m['variant'] ?? ''}',
    stockG: _d(m['stock']),
    coll: d.reference.parent.id,
    ref: d.reference,
  );
}

/// ⚠️ شِلّنا orderBy('variant') لتجنّب الاندكس المركّب.
/// هنفرز بالـ variant محليًا تحت.
final singlesStreamProvider = StreamProvider<List<InventoryRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('singles')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(_fromDoc).toList());
});

final blendsStreamProvider = StreamProvider<List<InventoryRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('blends')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(_fromDoc).toList());
});

int _blendRank(String name) {
  final n = name.trim();
  if (n.contains('اسبيشيال')) return 0;
  if (n.contains('مخصوص')) return 1;
  if (n.contains('كلاسيك')) return 2;
  if (n.contains('اسبريسو') || n.contains('اسبرسو')) return 3;
  return 4;
}

/// القائمة النهائية مرتبة: (Blends أوّلًا بتصنيفك) ثم Singles.
/// ملاحظة: ننسخ الليست قبل sort لتجنّب Unsupported operation.
final grindListProvider = Provider<List<InventoryRow>>((ref) {
  final singlesA = ref.watch(singlesStreamProvider);
  final blendsA = ref.watch(blendsStreamProvider);

  // ناخد نسخة قابلة للتعديل
  final singles = [
    ...singlesA.maybeWhen(data: (v) => v, orElse: () => const <InventoryRow>[]),
  ];
  final blends = [
    ...blendsA.maybeWhen(data: (v) => v, orElse: () => const <InventoryRow>[]),
  ];

  // ترتيب التوليفات
  blends.sort((a, b) {
    final r = _blendRank(a.name).compareTo(_blendRank(b.name));
    if (r != 0) return r;
    final byName = a.name.compareTo(b.name);
    if (byName != 0) return byName;
    return a.variant.compareTo(b.variant);
  });

  // ترتيب المفردة بالاسم ثم التحميص
  singles.sort((a, b) {
    final byName = a.name.compareTo(b.name);
    if (byName != 0) return byName;
    return a.variant.compareTo(b.variant);
  });

  return [...blends, ...singles];
});

/// خصم من المخزون (بدون أسعار)
Future<void> grindAndDeduct({
  required InventoryRow item,
  required double grams,
  required bool isSpiced, // متسيبة زي ما هي حتى لو ثابتة
}) async {
  if (grams <= 0) return;

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(item.ref);
    final m = snap.data() ?? {};
    final cur = _d(m['stock']);

    // حراسة صارمة داخل الترانزاكشن
    if (cur <= 0) {
      throw StateError('empty_stock'); // مفيش مخزون
    }
    if (grams > cur) {
      throw StateError('insufficient_stock'); // الكمية أكبر من المتاح
    }

    final newStock = (cur - grams).clamp(0.0, double.infinity);
    tx.update(item.ref, {'stock': newStock});
  });
}
