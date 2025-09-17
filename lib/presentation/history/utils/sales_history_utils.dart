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
