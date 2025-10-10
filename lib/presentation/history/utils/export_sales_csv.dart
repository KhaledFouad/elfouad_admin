import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:elfouad_admin/presentation/history/widgets/sale_tile.dart' as U;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'sales_history_utils.dart'
    as U; // inRangeLocal, effectiveTimeLocal, numD, titleLine, detectType, opDayKeyFromLocal

double _d(dynamic v) => U.numD(v);

String _fmt(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);
String _fmtDay(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

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
  ];
  if (rows.isEmpty) return '';
  String norm(Map<String, dynamic> c) {
    final name = (c['name'] ?? c['item_name'] ?? c['product_name'] ?? '')
        .toString();
    final variant = (c['variant'] ?? c['roast'] ?? '').toString();
    final grams = _d(c['grams']);
    final qty = _d(c['qty']);
    final price = _d(c['line_total_price']);
    final cost = _d(c['line_total_cost']);
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
    return 'Downloads (مدير التنزيلات)';
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
  final snap = await FirebaseFirestore.instance
      .collection('sales')
      .where('created_at', isLessThan: range.end.toUtc())
      .orderBy('created_at', descending: true)
      .get();

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

  for (final d in snap.docs) {
    final m = d.data();

    final createdAt =
        (m['created_at'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final settledRaw = m['settled_at'];
    final settledAt = settledRaw == null
        ? null
        : (settledRaw is Timestamp
              ? settledRaw.toDate()
              : DateTime.tryParse('$settledRaw'));

    final eff = U.effectiveTimeLocal(m);
    if (!U.inRangeLocal(eff, range)) continue; // نفس منطق الصفحة

    final type = (m['type'] ?? U.detectType(m)).toString();
    final title = U.titleLine(m, type);
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;

    final pricePerKg = _d(m['price_per_kg']);
    final costPerKg = _d(m['cost_per_kg']);
    final pricePerG = pricePerKg > 0
        ? pricePerKg / 1000.0
        : _d(m['price_per_g']);
    final costPerG = costPerKg > 0 ? costPerKg / 1000.0 : _d(m['cost_per_g']);

    final note = ((m['note'] ?? m['notes'] ?? '') as Object).toString();
    final opDay = U.opDayKeyFromLocal(eff);

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
      _d(m['total_price']).toStringAsFixed(2),
      _d(m['total_cost']).toStringAsFixed(2),
      _d(m['profit_total']).toStringAsFixed(2),
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
    throw Exception('لا توجد عمليات داخل المدى المحدد.');
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
