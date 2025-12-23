import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:elfouad_admin/core/app_strings.dart';

import 'sales_history_utils.dart'
    as history_utils; // inRangeLocal, effectiveTimeLocal, numD, titleLine, detectType, opDayKeyFromLocal

double _d(dynamic v) => history_utils.numD(v);

String _fmt(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);
String _fmtDay(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
DateTime _createdAtOf(Map<String, dynamic> m) {
  final v = m['created_at'];
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is num) {
    final raw = v.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return DateTime.tryParse('$v') ?? DateTime.fromMillisecondsSinceEpoch(0);
}

List<Map<String, dynamic>> _asListMap(dynamic v) {
  if (v is List) {
    return v
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .toList();
  }
  return const [];
}

String _componentsToText(Map<String, dynamic> m) {
  final rows = [
    ..._asListMap(m['components']),
    ..._asListMap(m['items']),
    ..._asListMap(m['lines']),
    ..._asListMap(m['cart_items']),
    ..._asListMap(m['order_items']),
    ..._asListMap(m['products']),
  ];
  if (rows.isEmpty) return '';
  String norm(Map<String, dynamic> c) {
    final name = (c['name'] ?? c['item_name'] ?? c['product_name'] ?? '')
        .toString();
    final variant = (c['variant'] ?? c['roast'] ?? '').toString();
    final grams = _d(c['grams'] ?? c['weight'] ?? c['gram']);
    final qty = _d(c['qty'] ?? c['quantity'] ?? c['count'] ?? c['pieces']);
    final price = _d(
      c['line_total_price'] ?? c['total_price'] ?? c['price'] ?? c['amount'],
    );
    final cost =
        _d(c['line_total_cost'] ?? c['total_cost'] ?? c['cost']);
    return '${name.replaceAll(',', '،')}|${variant.replaceAll(',', '،')}|'
        '${grams.toStringAsFixed(0)}|'
        '${qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty}|'
        '${price.toStringAsFixed(2)}|${cost.toStringAsFixed(2)}';
  }

  return rows.map(norm).join('  ||  ');
}

/// يحاول الحفظ في Downloads؛ لو فشل، يحفظ داخل Documents بتاع التطبيق.
/// بيرجع نص يوضح مكان الحفظ.
Future<String> _saveBytesSmart({
  required Uint8List bytes,
  required String baseNameNoExt,
  String ext = 'csv',
}) async {
  // 1) جرّب FileSaver (Downloads/MediaStore على أندرويد، بدون صلاحيات غالبًا)
  try {
    await FileSaver.instance.saveFile(
      name: baseNameNoExt,
      bytes: bytes,
      ext: ext,
      mimeType: MimeType.csv, // لبعض الأجهزة يفضل customMimeType: 'text/csv'
      // customMimeType: 'text/csv',
    );
    return AppStrings.downloadsLabel;
  } catch (e) {
    // 2) Fallback: احفظ داخل Documents للتطبيق
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$baseNameNoExt.$ext';
    final f = File(path);
    await f.writeAsBytes(bytes);
    return path;
  }
}

/// يصدّر العمليات داخل "effective time" للمدى المحدد إلى CSV.
/// بيرجع نص بيوضح مكان الحفظ (Downloads أو مسار الملف).
Future<String> exportSalesCsv(DateTimeRange range) async {
  final endUtc = range.end.toUtc();
  final endIso = endUtc.toIso8601String();
  final endMs = endUtc.millisecondsSinceEpoch;

  final snap = await FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isLessThan: endUtc)
      .orderBy('created_at', descending: true)
      .get();
  QuerySnapshot<Map<String, dynamic>>? snapStr;
  try {
    snapStr = await FirebaseFirestore.instance
        .collection('sales')
        .where('created_at', isLessThan: endIso)
        .orderBy('created_at', descending: true)
        .get();
  } catch (_) {
    snapStr = null;
  }
  QuerySnapshot<Map<String, dynamic>>? snapNum;
  try {
    snapNum = await FirebaseFirestore.instance
        .collection('sales')
        .where('created_at', isLessThan: endMs)
        .orderBy('created_at', descending: true)
        .get();
  } catch (_) {
    snapNum = null;
  }

  final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final d in snap.docs) {
    docsById[d.id] = d;
  }
  if (snapStr != null) {
    for (final d in snapStr.docs) {
      docsById[d.id] = d;
    }
  }
  if (snapNum != null) {
    for (final d in snapNum.docs) {
      docsById[d.id] = d;
    }
  }
  final docs = docsById.values.toList()
    ..sort((a, b) => _createdAtOf(b.data()).compareTo(_createdAtOf(a.data())));

  final rows = <List<dynamic>>[];

  rows.add([
    'sale_id',
    'type',
    'title',
    'created_at',
    'effective_time',
    'settled_at',
    'is_deferred',
    'paid',
    'due_amount',
    'total_price',
    'total_cost',
    'profit_total',
    'quantity',
    'grams',
    'price_per_kg',
    'cost_per_kg',
    'price_per_g',
    'cost_per_g',
    'is_spiced',
    'spice_rate_per_kg',
    'spice_amount',
    'is_complimentary',
    'note',
    'op_day',
    'components',
  ]);

  for (final d in docs) {
    final m = d.data();

    final totals = history_utils.saleTotalsWithFallback(m);
    final createdAt = history_utils.createdAtUtcOf(m).toLocal();
    final settledRaw = m['settled_at'];
    final settledAt = settledRaw == null
        ? null
        : (settledRaw is Timestamp
              ? settledRaw.toDate()
              : (settledRaw is num
                    ? DateTime.fromMillisecondsSinceEpoch(
                      settledRaw < 10000000000
                          ? settledRaw.toInt() * 1000
                          : settledRaw.toInt(),
                    )
                    : DateTime.tryParse('$settledRaw')));

    final eff = history_utils.effectiveTimeLocal(m);
    if (!history_utils.inRangeLocal(eff, range)) continue; // نفس منطق الصفحة

    final type = (m['type'] ?? history_utils.detectType(m)).toString();
    final title = history_utils.titleLine(m, type);
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;

    final pricePerKg = _d(m['price_per_kg']);
    final costPerKg = _d(m['cost_per_kg']);
    final pricePerG = pricePerKg > 0
        ? pricePerKg / 1000.0
        : _d(m['price_per_g']);
    final costPerG = costPerKg > 0 ? costPerKg / 1000.0 : _d(m['cost_per_g']);

    final note = ((m['note'] ?? m['notes'] ?? '') as Object).toString();
    final opDay = history_utils.opDayKeyFromLocal(eff);

    rows.add([
      d.id,
      type,
      title,
      _fmt(createdAt),
      _fmt(eff),
      settledAt != null ? _fmt(settledAt) : '',
      isDeferred ? 1 : 0,
      paid ? 1 : 0,
      _d(m['due_amount']).toStringAsFixed(2),
      totals.price.toStringAsFixed(2),
      totals.cost.toStringAsFixed(2),
      totals.profit.toStringAsFixed(2),
      _d(m['quantity']),
      _d(m['grams']),
      pricePerKg,
      costPerKg,
      pricePerG,
      costPerG,
      (m['is_spiced'] ?? false) == true ? 1 : 0,
      _d(m['spice_rate_per_kg']),
      _d(m['spice_amount']),
      (m['is_complimentary'] ?? false) == true ? 1 : 0,
      note.replaceAll('\n', ' '),
      opDay,
      _componentsToText(m),
    ]);
  }

  if (rows.length == 1) {
    throw Exception(AppStrings.noSalesInRangeForExport);
  }

  final csv = const ListToCsvConverter().convert(rows);
  final bytes = Uint8List.fromList(utf8.encode(csv));

  final name =
      'sales_${_fmtDay(range.start)}_${_fmtDay(range.end.subtract(const Duration(minutes: 1)))}';

  // نحاول Downloads، ولو فشل نكتب داخل Documents ونرجّع المسار
  final where = await _saveBytesSmart(
    bytes: bytes,
    baseNameNoExt: name,
    ext: 'csv',
  );
  return where;
}
