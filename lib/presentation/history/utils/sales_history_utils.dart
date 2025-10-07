import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shift -4h to get the operational day key, then format as yyyy-MM-dd.
String dayKeyFromUtc(DateTime createdUtc) {
  final shifted = createdUtc.subtract(const Duration(hours: 4));
  return '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
}

/// Group docs by day key.
Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
groupByOperationalDay(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final byDay = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  for (final d in docs) {
    final m = d.data();
    final ts =
        (m['created_at'] as Timestamp?)?.toDate() ??
        DateTime.tryParse(m['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final dayKey = dayKeyFromUtc(ts);
    byDay.putIfAbsent(dayKey, () => []).add(d);
  }
  return byDay;
}

double sumField(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
  String k,
) {
  double s = 0;
  for (final e in es) {
    s += numD(e.data()[k]);
  }
  return s;
}

int sumDrinkCups(List<QueryDocumentSnapshot<Map<String, dynamic>>> es) {
  int s = 0;
  for (final e in es) {
    final m = e.data();
    final t = (m['type'] ?? '').toString();
    if (t == 'drink') {
      final q = numD(m['quantity']);
      s += (q > 0 ? q.round() : 1);
    }
  }
  return s;
}

double sumBeansGrams(List<QueryDocumentSnapshot<Map<String, dynamic>>> es) {
  double s = 0;
  for (final e in es) {
    final m = e.data();
    final t = (m['type'] ?? '').toString();
    if (t == 'single' || t == 'ready_blend') {
      s += numD(m['grams']);
    } else if (t == 'custom_blend') {
      s += numD(m['total_grams']);
    }
  }
  return s;
}

/// ==== Tile helpers ====
double numD(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}

List<Map<String, dynamic>> asListMap(dynamic v) {
  if (v is List) {
    return v
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .toList();
  }
  return const [];
}

String detectType(Map<String, dynamic> m) {
  final t = (m['type'] ?? '').toString();
  if (t.isNotEmpty) return t;
  if (m.containsKey('components')) return 'custom_blend';
  if (m.containsKey('drink_id') || m.containsKey('drink_name')) return 'drink';
  if (m.containsKey('single_id') || m.containsKey('single_name')) {
    return 'single';
  }
  if (m.containsKey('blend_id') || m.containsKey('blend_name')) {
    return 'ready_blend';
  }
  final items = asListMap(m['items']);
  if (items.isNotEmpty && items.any((x) => x.containsKey('grams'))) {
    return 'single';
  }
  return 'unknown';
}

List<Map<String, dynamic>> extractComponents(
  Map<String, dynamic> m,
  String type,
) {
  final components = asListMap(m['components']);
  if (components.isNotEmpty) return components.map(normalizeRow).toList();

  final items = asListMap(m['items']);
  if (items.isNotEmpty) return items.map(normalizeRow).toList();

  final lines = asListMap(m['lines']);
  if (lines.isNotEmpty) return lines.map(normalizeRow).toList();

  if (type == 'drink') {
    final name = (m['drink_name'] ?? m['name'] ?? 'مشروب').toString();
    final variant = (m['roast'] ?? m['variant'] ?? '').toString();
    final qty = numD(m['quantity'] ?? m['qty'] ?? 1);
    final unit = (m['unit'] ?? 'cup').toString();
    final unitPrice = numD(m['unit_price']);
    final unitCost = numD(m['unit_cost']);
    final totalPrice = numD(m['total_price']);
    final totalCost = numD(m['total_cost']);
    return [
      {
        'name': name,
        'variant': variant,
        'qty': qty,
        'unit': unit,
        'grams': 0,
        'line_total_price': totalPrice > 0 ? totalPrice : unitPrice * qty,
        'line_total_cost': totalCost > 0 ? totalCost : unitCost * qty,
      },
    ];
  }

  if (type == 'single' || type == 'ready_blend') {
    final name = (m['name'] ?? '').toString();
    final variant = (m['variant'] ?? '').toString();
    final grams = numD(m['grams']);
    final totalPrice = numD(m['total_price']);
    final totalCost = numD(m['total_cost']);
    return [
      {
        'name': name,
        'variant': variant,
        'grams': grams,
        'qty': 0,
        'unit': 'g',
        'line_total_price': totalPrice,
        'line_total_cost': totalCost,
      },
    ];
  }

  return const [];
}
// ==== Deferred settlement helpers ===========================================

/// تسوية عملية أجل: تعليمها مدفوعة + تصفير المستحق وتثبيت الربح لو كان لسه 0
Future<void> settleDeferredSale(String docId) async {
  final ref = FirebaseFirestore.instance.collection('sales').doc(docId);
  await FirebaseFirestore.instance.runTransaction((trx) async {
    final snap = await trx.get(ref);
    final data = snap.data() as Map<String, dynamic>? ?? {};

    double _numD(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '0') ?? 0;

    final totalPrice = _numD(data['total_price']);
    final totalCost = _numD(data['total_cost']);
    final currentProfit = _numD(data['profit_total']);

    // لو الربح مش متسجل، نحسبه بعد السداد
    final newProfit = currentProfit != 0
        ? currentProfit
        : (totalPrice - totalCost);

    trx.update(ref, {
      'paid': true,
      'due_amount': 0,
      'profit_total': newProfit,
      'updated_at': FieldValue.serverTimestamp(),
    });
  });
}

/// زرّ "تم الدفع" يُعرض فقط لو العملية أجل وغير مدفوعة وفيه مستحق > 0
Widget deferredSettleButton({
  required BuildContext context,
  required String docId,
  required bool isDeferred,
  required bool paid,
  required double dueAmount,
}) {
  if (!(isDeferred && !paid && dueAmount > 0)) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(
            const Color.fromRGBO(93, 64, 55, 1),
          ),
        ),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('تأكيد السداد'),
              content: Text(
                'سيتم تثبيت دفع ${dueAmount.toStringAsFixed(2)} جم.\nهل تريد المتابعة؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تم الدفع'),
                ),
              ],
            ),
          );
          if (ok == true) {
            try {
              await settleDeferredSale(docId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تسوية العملية المؤجّلة')),
              );
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('تعذّر التسوية: $e')));
            }
          }
        },
        icon: const Icon(Icons.payments),
        label: const Text('تم الدفع'),
      ),
    ),
  );
}

/// لفّ عنصر المكوّن ليضيف زر التسوية أسفله عند الحاجة
Widget componentRowWithSettle(
  Map<String, dynamic> component,
  Map<String, dynamic> sale,
  BuildContext context,
  String docId,
) {
  final row = componentRow(component);
  // نقرأ حالات الأجل من بيانات العملية الأصلية
  final bool isDeferred = (sale['is_deferred'] ?? false) == true;
  final bool paid = (sale['paid'] ?? false) == true;
  final double dueAmt = numD(sale['due_amount']);

  // نزود الزر أسفل صف س/ت بنفس الـpadding/Align المطلوب
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [row],
  );
}

Map<String, dynamic> normalizeRow(Map<String, dynamic> c) {
  String name = (c['name'] ?? c['item_name'] ?? c['product_name'] ?? '')
      .toString();
  String variant = (c['variant'] ?? c['roast'] ?? '').toString();
  double grams = numD(c['grams'] ?? c['weight'] ?? 0);
  double qty = numD(c['qty'] ?? c['count'] ?? 0);
  String unit = (c['unit'] ?? (grams > 0 ? 'g' : '')).toString();
  double linePrice = numD(c['line_total_price'] ?? c['total_price'] ?? 0);
  double lineCost = numD(c['line_total_cost'] ?? c['total_cost'] ?? 0);
  return {
    'name': name,
    'variant': variant,
    'grams': grams,
    'qty': qty,
    'unit': unit,
    'line_total_price': linePrice,
    'line_total_cost': lineCost,
  };
}

IconData iconForType(String t) {
  switch (t) {
    case 'drink':
      return Icons.local_cafe;
    case 'single':
      return Icons.coffee_outlined;
    case 'ready_blend':
      return Icons.blender_outlined;
    case 'custom_blend':
      return Icons.auto_awesome_mosaic;
    default:
      return Icons.receipt_long;
  }
}

String fmtTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String titleLine(Map<String, dynamic> m, String type) {
  String name = (m['name'] ?? '').toString();
  String variant = (m['variant'] ?? m['roast'] ?? '').toString();
  String labelNV = variant.isNotEmpty ? '$name $variant' : name;

  switch (type) {
    case 'drink':
      final q = numD(m['quantity']) > 0
          ? numD(m['quantity']).toStringAsFixed(0)
          : '1';
      final dn = (m['drink_name'] ?? '').toString();
      final finalName = labelNV.isNotEmpty
          ? labelNV
          : (dn.isNotEmpty ? dn : 'مشروب');
      return 'مشروب - $q $finalName';
    case 'single':
      {
        final g = numD(m['grams']).toStringAsFixed(0);
        final lbl = labelNV.isNotEmpty ? labelNV : name;
        return 'صنف منفرد - $g جم ${lbl.isNotEmpty ? lbl : ''}'.trim();
      }
    case 'ready_blend':
      {
        final g = numD(m['grams']).toStringAsFixed(0);
        final lbl = labelNV.isNotEmpty ? labelNV : name;
        return 'توليفة جاهزة - $g جم ${lbl.isNotEmpty ? lbl : ''}'.trim();
      }
    case 'custom_blend':
      return 'توليفة العميل';
    default:
      return 'عملية';
  }
}

Widget kv(String k, double v) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$k: ', style: const TextStyle(color: Colors.black54)),
      Text(
        v.toStringAsFixed(2),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

Widget componentRow(Map<String, dynamic> c) {
  final name = (c['name'] ?? '').toString();
  final variant = (c['variant'] ?? '').toString();
  final unit = (c['unit'] ?? '').toString();
  final qty = numD(c['qty']);
  final grams = numD(c['grams']);
  final price = numD(c['line_total_price']);
  final cost = numD(c['line_total_cost']);

  final label = variant.isNotEmpty ? '$name - $variant' : name;
  final qtyText = grams > 0
      ? '${grams.toStringAsFixed(0)} جم'
      : (qty > 0 ? '$qty ${unit.isEmpty ? "" : unit}' : '');

  return ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: const Icon(Icons.circle, size: 8),
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (qtyText.isNotEmpty)
          Text(qtyText, style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 12),
        Text(
          'س:${price.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Text(
          'ت:${cost.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    ),
  );
}

double spiceRatePerKgForSingle(String name) {
  final n = name.trim();
  if (n.contains('كولوم') || n.contains('كولومبي')) return 80.0;
  if (n.contains('برازي') || n.contains('برازيلي')) return 60.0;
  if (n.contains('حبش') || n.contains('حبشي')) return 60.0;
  if (n.contains('هند') || n.contains('هندي')) return 60.0;
  return 40.0;
}
// ====== INVENTORY SYNC (edit/delete) ========================================

class _StockUsage {
  final Map<String, double> singles; // single_id/item_id -> grams
  final Map<String, double> blends; // blend_id/item_id -> grams
  _StockUsage({Map<String, double>? singles, Map<String, double>? blends})
    : singles = singles ?? {},
      blends = blends ?? {};
}

_StockUsage _stockUsageForSale(Map<String, dynamic> m) {
  double g(dynamic v) => numD(v);
  String s(dynamic v) => (v ?? '').toString();

  final usage = _StockUsage();
  final type = detectType(m);

  void addSingle(String? id, double grams) {
    if (id == null || id.isEmpty || grams <= 0) return;
    usage.singles[id] = (usage.singles[id] ?? 0) + grams;
  }

  void addBlend(String? id, double grams) {
    if (id == null || id.isEmpty || grams <= 0) return;
    usage.blends[id] = (usage.blends[id] ?? 0) + grams;
  }

  if (type == 'single') {
    final id = s(
      m['single_id'].toString().isNotEmpty ? m['single_id'] : m['item_id'],
    );
    addSingle(id, g(m['grams']));
  } else if (type == 'ready_blend') {
    final id = s(
      m['blend_id'].toString().isNotEmpty ? m['blend_id'] : m['item_id'],
    );
    addBlend(id, g(m['grams']));
  } else if (type == 'custom_blend') {
    final comps = asListMap(m['components']);
    final items = asListMap(m['items']);
    final lines = asListMap(m['lines']);
    final rows = comps.isNotEmpty ? comps : (items.isNotEmpty ? items : lines);

    for (final r in rows) {
      final grams = g(r['grams']);
      // المكوّنات عادة بتبقى من singles
      final id = s(r['single_id'] ?? r['item_id'] ?? r['id']);
      if (id.isNotEmpty) {
        addSingle(id, grams);
      }
    }
  }

  return usage;
}

Future<void> _applyToInventory({
  required String collection, // 'singles' أو 'blends'
  required String docId,
  required double deltaGrams, // + يزيد / - ينقص
}) async {
  if (docId.isEmpty || deltaGrams == 0) return;
  final ref = FirebaseFirestore.instance.collection(collection).doc(docId);

  await FirebaseFirestore.instance.runTransaction((trx) async {
    final snap = await trx.get(ref);
    final data = (snap.data() as Map<String, dynamic>?) ?? {};

    // نفضّل 'stock' ثم أي مفتاح شائع
    final candidates = [
      'stock',
      'stock_grams',
      'available_grams',
      'in_stock_grams',
      'grams_in_stock',
    ];

    // دور على أول مفتاح موجود رقميًا
    String? stockKey;
    for (final k in candidates) {
      final v = data[k];
      if (v is num) {
        stockKey = k;
        break;
      }
      if (v is String && double.tryParse(v.replaceAll(',', '.')) != null) {
        stockKey = k;
        break;
      }
    }

    // لو مفيش ولا واحد، هننشئ/نستخدم 'stock'
    stockKey ??= 'stock';

    final currentNum = data[stockKey];
    double current = 0.0;
    if (currentNum is num) current = currentNum.toDouble();
    if (currentNum is String) {
      current = double.tryParse(currentNum.replaceAll(',', '.')) ?? 0.0;
    }

    trx.update(ref, {stockKey: current + deltaGrams});
  });
}

/// استرجاع المخزون عند حذف عملية
Future<void> revertStockForSale(Map<String, dynamic> sale) async {
  final u = _stockUsageForSale(sale);
  // نحط الجرامات تاني (علامة +)
  for (final e in u.singles.entries) {
    await _applyToInventory(
      collection: 'singles',
      docId: e.key,
      deltaGrams: e.value,
    );
  }
  for (final e in u.blends.entries) {
    await _applyToInventory(
      collection: 'blends',
      docId: e.key,
      deltaGrams: e.value,
    );
  }
}

/// تطبيق فرق المخزون بعد التعديل (after - before)
Future<void> applyStockDiffForEdit({
  required Map<String, dynamic> before,
  required Map<String, dynamic> after,
}) async {
  final b = _stockUsageForSale(before);
  final a = _stockUsageForSale(after);

  // اجمع كل المفاتيح
  final singleKeys = {...b.singles.keys, ...a.singles.keys};
  final blendKeys = {...b.blends.keys, ...a.blends.keys};

  for (final id in singleKeys) {
    final prev = b.singles[id] ?? 0;
    final next = a.singles[id] ?? 0;
    final diff = next - prev; // لو زاد الاستهلاك → diff موجب
    if (diff != 0) {
      await _applyToInventory(
        collection: 'singles',
        docId: id,
        deltaGrams: -diff, // الاستهلاك يزيد → المخزون ينقص
      );
    }
  }

  for (final id in blendKeys) {
    final prev = b.blends[id] ?? 0;
    final next = a.blends[id] ?? 0;
    final diff = next - prev;
    if (diff != 0) {
      await _applyToInventory(
        collection: 'blends',
        docId: id,
        deltaGrams: -diff,
      );
    }
  }
}
// ==== Inventory stock adjust helpers ========================================

class _StockOp {
  final DocumentReference<Map<String, dynamic>> ref;
  final double grams;
  _StockOp(this.ref, this.grams);
}

double _numDYN(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

DocumentReference<Map<String, dynamic>>? _refForSingle(String? id) {
  if (id == null || id.isEmpty) return null;
  return FirebaseFirestore.instance.collection('singles').doc(id);
}

DocumentReference<Map<String, dynamic>>? _refForBlend(String? id) {
  if (id == null || id.isEmpty) return null;
  return FirebaseFirestore.instance.collection('blends').doc(id);
}

/// يحاول استخراج عمليات خصم/إضافة المخزون من مستند البيع
List<_StockOp> _extractStockOpsFromSale(Map<String, dynamic> m) {
  final type = '${m['type'] ?? ''}'.trim();

  DocumentReference<Map<String, dynamic>>? _pickRef(Map<String, dynamic> x) {
    final sid = (x['single_id'] ?? x['singleId'] ?? '').toString();
    final bid = (x['blend_id'] ?? x['blendId'] ?? '').toString();
    if (sid.isNotEmpty) return _refForSingle(sid);
    if (bid.isNotEmpty) return _refForBlend(bid);

    final itemId = (x['item_id'] ?? x['itemId'] ?? '').toString();
    final itemType = (x['item_type'] ?? x['itemType'] ?? '')
        .toString()
        .toLowerCase();
    if (itemId.isNotEmpty) {
      if (itemType.contains('blend')) return _refForBlend(itemId);
      // default single
      return _refForSingle(itemId);
    }
    return null;
  }

  if (type == 'single' || type == 'ready_blend') {
    DocumentReference<Map<String, dynamic>>? ref;
    if (type == 'single') {
      ref = _pickRef({
        'single_id': m['single_id'],
        'item_id': m['item_id'],
        'item_type': 'single',
      });
    } else {
      ref = _pickRef({
        'blend_id': m['blend_id'],
        'item_id': m['item_id'],
        'item_type': 'blend',
      });
    }
    final g = _numDYN(m['grams']);
    if (ref != null && g > 0) return [_StockOp(ref, g)];
    return const [];
  }

  if (type == 'custom_blend') {
    List<Map<String, dynamic>> _asList(dynamic v) {
      if (v is List) {
        return v
            .map(
              (e) =>
                  (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
            )
            .toList();
      }
      return const [];
    }

    final rows = () {
      final c = _asList(m['components']);
      if (c.isNotEmpty) return c;
      final it = _asList(m['items']);
      if (it.isNotEmpty) return it;
      return _asList(m['lines']);
    }();

    final ops = <_StockOp>[];
    for (final r in rows) {
      final ref = _pickRef(r);
      final grams = _numDYN(r['grams'] ?? r['weight'] ?? 0);
      if (ref != null && grams > 0) ops.add(_StockOp(ref, grams));
    }
    return ops;
  }

  return const [];
}

Future<void> _applyStockOps(
  List<_StockOp> ops,
  double sign,
  Transaction tx,
) async {
  final byRef = <DocumentReference<Map<String, dynamic>>, double>{};
  for (final op in ops) {
    byRef[op.ref] = (byRef[op.ref] ?? 0.0) + (op.grams * sign);
  }
  for (final entry in byRef.entries) {
    final ref = entry.key;
    final delta = entry.value; // قد يكون موجب (إضافة) أو سالب (خصم)
    final snap = await tx.get(ref);
    final cur = _numDYN(snap.data()?['stock']);
    tx.update(ref, {'stock': cur + delta});
  }
}

/// عند حذف بيع: رجّع المخزون ثم احذف المستند داخل نفس الترانزاكشن
Future<void> restoreStockOnSaleDelete(
  DocumentReference<Map<String, dynamic>> saleRef,
) async {
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(saleRef);
    final data = (snap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final ops = _extractStockOpsFromSale(data);
    await _applyStockOps(ops, 1.0, tx); // 1.0 = إضافة راجعة
    tx.delete(saleRef);
  });
}

/// عند تعديل بيع: طبّق فرق المخزون = (الجرامات بعد) - (الجرامات قبل)
Future<void> applyStockDeltaOnSaleEdit({
  required Map<String, dynamic> before,
  required Map<String, dynamic> after,
}) async {
  Map<DocumentReference<Map<String, dynamic>>, double> _collapse(
    List<_StockOp> ops,
  ) {
    final m = <DocumentReference<Map<String, dynamic>>, double>{};
    for (final o in ops) {
      m[o.ref] = (m[o.ref] ?? 0.0) + o.grams;
    }
    return m;
  }

  final b = _collapse(_extractStockOpsFromSale(before));
  final a = _collapse(_extractStockOpsFromSale(after));

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final allRefs = <DocumentReference<Map<String, dynamic>>>{
      ...b.keys,
      ...a.keys,
    };
    for (final ref in allRefs) {
      final newG = a[ref] ?? 0.0;
      final oldG = b[ref] ?? 0.0;
      final delta =
          newG - oldG; // موجب = بيع زاد → هنخصم, سالب = بيع قل → هنضيف
      if (delta == 0.0) continue;

      final snap = await tx.get(ref);
      final cur = _numDYN(snap.data()?['stock']);
      tx.update(ref, {'stock': cur - delta});
    }
  });
}
