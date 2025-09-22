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

final singlesStreamProvider = StreamProvider<List<InventoryRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('singles')
      .orderBy('name') // 👈 شيل orderBy('variant')
      .snapshots()
      .map((s) {
        final list = s.docs.map(_fromDoc).toList();
        list.sort((a, b) {
          final c = a.name.compareTo(b.name);
          if (c != 0) return c;
          return a.variant.compareTo(b.variant);
        });
        return list;
      })
      .handleError((e, st) {
        // اختياري: سجّل الخطأ بدل ما يقطع الستريم
        // debugPrint('singles stream error: $e');
      });
});

final blendsStreamProvider = StreamProvider<List<InventoryRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('blends')
      .orderBy('name') // 👈 شيل orderBy('variant')
      .snapshots()
      .map((s) {
        final list = s.docs.map(_fromDoc).toList();
        list.sort((a, b) {
          final c = a.name.compareTo(b.name);
          if (c != 0) return c;
          return a.variant.compareTo(b.variant);
        });
        return list;
      })
      .handleError((e, st) {
        // debugPrint('blends stream error: $e');
      });
});

int _blendRank(String name) {
  final n = name.trim();
  if (n.contains('اسبيشيال')) return 0;
  if (n.contains('مخصوص')) return 1;
  if (n.contains('كلاسيك')) return 2;
  if (n.contains('اسبريسو') || n.contains('اسبرسو')) return 3;
  return 4;
}

final grindListProvider = Provider<List<InventoryRow>>((ref) {
  final singlesA = ref.watch(singlesStreamProvider);
  final blendsA = ref.watch(blendsStreamProvider);

  final singles = singlesA.maybeWhen(
    data: (v) => [...v],
    orElse: () => <InventoryRow>[],
  );
  final blends = blendsA.maybeWhen(
    data: (v) => [...v],
    orElse: () => <InventoryRow>[],
  );

  blends.sort((a, b) {
    final r = _blendRank(a.name).compareTo(_blendRank(b.name));
    if (r != 0) return r;
    final c = a.name.compareTo(b.name);
    if (c != 0) return c;
    return a.variant.compareTo(b.variant);
  });

  singles.sort((a, b) {
    final c = a.name.compareTo(b.name);
    if (c != 0) return c;
    return a.variant.compareTo(b.variant);
  });

  return [...blends, ...singles];
});

/// خصم آمن داخل ترانزاكشن (يمنع الخصم لو المخزون صفر أو أقل من المطلوب)
Future<void> grindAndDeduct({
  required InventoryRow item,
  required double grams,
  required bool isSpiced, // احتفظنا به للتوافق
}) async {
  if (grams <= 0) return;

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(item.ref);
    final m = snap.data() ?? {};
    final cur = _d(m['stock']);

    if (cur <= 0) {
      throw StateError('empty_stock');
    }
    if (grams > cur) {
      throw StateError('insufficient_stock');
    }

    final newStock = (cur - grams).clamp(0.0, double.infinity);
    tx.update(item.ref, {'stock': newStock});
  });
}
