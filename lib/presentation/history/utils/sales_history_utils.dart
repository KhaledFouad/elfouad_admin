import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';

/// ========== مفاتيح يوم التشغيل (4 ص) ==========
String dayKeyFromUtc(DateTime createdUtc) {
  final shifted = createdUtc.subtract(const Duration(hours: 4));
  return '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
}

/// تحويل آمن لأرقام
double numD(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}

/// فحص الأجل غير المدفوع

/// قراءة created_at كـ UTC (لو String/Timestamp)
DateTime createdAtUtcOf(Map<String, dynamic> m) {
  final ts =
      (m['created_at'] as Timestamp?)?.toDate() ??
      DateTime.tryParse(m['created_at']?.toString() ?? '');
  return (ts?.toUtc()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// وقت العرض للتايل: للأجل المُرحّل نخليه 05:00 من اليوم الحالي
DateTime viewCreatedAtFor(Map<String, dynamic> m) {
  final now = DateTime.now().toUtc();
  final nowKey = dayKeyFromUtc(now);
  final orig = createdAtUtcOf(m);
  final origKey = dayKeyFromUtc(orig);
  if (isUnpaidDeferredMap(m) && origKey.compareTo(nowKey) < 0) {
    // 05:00 UTC لليوم الحالي (عرض فقط)
    return DateTime.utc(now.year, now.month, now.day, 5, 0);
  }
  return orig;
}

/// لو العملية فيها تاريخ أصلي محفوظ
DateTime? originalCreatedAtIfAny(Map<String, dynamic> m) {
  final t = (m['original_created_at'] as Timestamp?)?.toDate();
  if (t != null) return t.toUtc();
  return null;
}

/// Group docs by (operational) day with rollover of unpaid deferred to today.
Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
groupByOperationalDayWithRollover(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final nowKey = dayKeyFromUtc(DateTime.now().toUtc());
  final byDay = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  for (final d in docs) {
    final m = d.data();
    final orig = createdAtUtcOf(m);
    String key = dayKeyFromUtc(orig);
    if (isUnpaidDeferredMap(m) && key.compareTo(nowKey) < 0) {
      key = nowKey; // نرحّل لليوم الحالي
    }
    byDay.putIfAbsent(key, () => []).add(d);
  }
  return byDay;
}

/// ==== summations ====
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
// ====== Shared helpers ======

bool isUnpaidDeferred(Map<String, dynamic> m) {
  final isDeferred = (m['is_deferred'] ?? false) == true;
  final paid = (m['paid'] ?? (!isDeferred)) == true;
  return isDeferred && !paid;
}

/// ==== تفاصيل العناصر (زي الموجود عندك) ====
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
  if (m.containsKey('single_id') || m.containsKey('single_name'))
    return 'single';
  if (m.containsKey('blend_id') || m.containsKey('blend_name'))
    return 'ready_blend';
  final items = asListMap(m['items']);
  if (items.isNotEmpty && items.any((x) => x.containsKey('grams')))
    return 'single';
  return 'unknown';
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

String fmtDateTime(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

/// ==== Deferred settlement helpers ===========================================

double spiceRatePerKgForSingle(String name) {
  final n = name.trim();
  if (n.contains('كولوم') || n.contains('كولومبي')) return 80.0;
  if (n.contains('برازي') || n.contains('برازيلي')) return 60.0;
  if (n.contains('حبش') || n.contains('حبشي')) return 60.0;
  if (n.contains('هند') || n.contains('هندي')) return 60.0;
  return 40.0;
}

/// تسوية عملية أجل: نعلّم مدفوعة + نحفظ التاريخ الأصلي + ننقلها لليوم الحالي
Future<void> settleDeferredSale(String docId) async {
  final ref = FirebaseFirestore.instance.collection('sales').doc(docId);
  await FirebaseFirestore.instance.runTransaction((trx) async {
    final snap = await trx.get(ref);
    final data = snap.data() as Map<String, dynamic>? ?? {};

    double _n(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '0') ?? 0;

    final totalPrice = _n(data['total_price']);
    final totalCost = _n(data['total_cost']);
    final currentProfit = _n(data['profit_total']);

    final newProfit = currentProfit != 0
        ? currentProfit
        : (totalPrice - totalCost);

    final oldCreated = data['created_at'];

    trx.update(ref, {
      'paid': true,
      'due_amount': 0,
      'profit_total': newProfit,
      // احفظ التاريخ الأصلي لو مش محفوظ
      if (!data.containsKey('original_created_at'))
        'original_created_at': oldCreated,
      // انقل العملية لليوم الحالي فعليًا
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  });
}

DateTime _utc(DateTime d) => d.toUtc();

String _safeStr(dynamic v) => (v ?? '').toString();
double _numD(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}

String _fmtDateTimeLocal(DateTime? dt) {
  if (dt == null) return '';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$mm';
}

/// يبني الـ Excel بصفحتين:
/// 1) Sales: مستوى العملية
/// 2) Lines: تفصيل المكونات (لو موجودة)
Uint8List _buildExcelBytes({
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> lines,
}) {
  final excel = Excel.createExcel();
  final s1 = excel['Sales'];
  final s2 = excel['Lines'];

  // رؤوس الجداول
  s1.appendRow([
    'sale_id',
    'created_at',
    'effective_time',
    'settled_at',
    'type',
    'name',
    'variant',
    'grams',
    'quantity',
    'total_price',
    'total_cost',
    'profit_total',
    'is_deferred',
    'paid',
    'due_amount',
    'is_spiced',
    'spice_amount',
    'notes',
  ]);

  for (final m in sales) {
    s1.appendRow([
      _safeStr(m['id']),
      _safeStr(m['created_at']),
      _safeStr(m['effective_time']),
      _safeStr(m['settled_at']),
      _safeStr(m['type']),
      _safeStr(m['name']),
      _safeStr(m['variant']),
      _numD(m['grams']),
      _numD(m['quantity']),
      _numD(m['total_price']),
      _numD(m['total_cost']),
      _numD(m['profit_total']),
      (m['is_deferred'] == true) ? '1' : '0',
      (m['paid'] == true) ? '1' : '0',
      _numD(m['due_amount']),
      (m['is_spiced'] == true) ? '1' : '0',
      _numD(m['spice_amount']),
      _safeStr(m['notes']),
    ]);
  }

  s2.appendRow([
    'sale_id',
    'row_idx',
    'name',
    'variant',
    'unit',
    'qty',
    'grams',
    'line_total_price',
    'line_total_cost',
  ]);

  for (final r in lines) {
    s2.appendRow([
      _safeStr(r['sale_id']),
      _numD(r['row_idx']),
      _safeStr(r['name']),
      _safeStr(r['variant']),
      _safeStr(r['unit']),
      _numD(r['qty']),
      _numD(r['grams']),
      _numD(r['line_total_price']),
      _numD(r['line_total_cost']),
    ]);
  }

  excel.setDefaultSheet('Sales');
  final bytes = excel.encode()!;
  return Uint8List.fromList(bytes);
}

/// نفس منطق نطاق 4ص → 4ص
bool inRangeLocal(DateTime t, DateTimeRange r) {
  return !t.isBefore(r.start) && t.isBefore(r.end);
}

/// نفس فكرة الوقت الفعّال اللي عندك (الأجل غير المدفوع → اليوم 05:00)
DateTime effectiveTimeLocal(Map<String, dynamic> m) {
  final createdAt =
      (m['created_at'] as Timestamp?)?.toDate() ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final settledAtRaw = m['settled_at'];
  final settledAt = settledAtRaw == null
      ? null
      : (settledAtRaw is Timestamp
            ? settledAtRaw.toDate()
            : DateTime.tryParse('$settledAtRaw'));
  final isDeferred = (m['is_deferred'] ?? m['is_credit'] ?? false) == true;
  final paid = (m['paid'] ?? (!isDeferred)) == true;

  if (isDeferred && !paid) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 5);
  }
  if (paid && settledAt != null) return settledAt;
  return createdAt;
}

/// استخراج مكونات الصفقة كسطور بسيطة
List<Map<String, dynamic>> _extractLines(
  String saleId,
  Map<String, dynamic> m,
) {
  List<Map<String, dynamic>> asList(dynamic v) {
    if (v is List) {
      return v
          .map(
            (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
          )
          .toList();
    }
    return const [];
  }

  final rows = <Map<String, dynamic>>[];
  final candidates = [
    ...asList(m['components']),
    ...asList(m['items']),
    ...asList(m['lines']),
  ];
  int idx = 0;
  for (final c in candidates) {
    rows.add({
      'sale_id': saleId,
      'row_idx': idx++,
      'name': _safeStr(c['name'] ?? c['item_name'] ?? c['product_name']),
      'variant': _safeStr(c['variant'] ?? c['roast']),
      'unit': _safeStr(c['unit']),
      'qty': _numD(c['qty']),
      'grams': _numD(c['grams']),
      'line_total_price': _numD(c['line_total_price']),
      'line_total_cost': _numD(c['line_total_cost']),
    });
  }
  return rows;
}

/// التصدير: بيحفظ مباشرة في Downloads ويعرض SnackBar فيه المسار + زر فتح.
/// لو فشل الحفظ، بيعمل مشاركة للملف كبديل.
Future<void> exportSalesExcelFromFilter(
  BuildContext context,
  DateTimeRange range,
) async {
  // اقفل أي شيت/دايالوج مفتوح قبل ما نبدأ
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  }

  // لودينج بسيط
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final startUtc = _utc(range.start);
    final endUtc = _utc(range.end);

    // Query أساسي بالنطاق (4ص→4ص)
    final qs = await FirebaseFirestore.instance
        .collection('sales')
        .where('created_at', isGreaterThanOrEqualTo: startUtc)
        .where('created_at', isLessThan: endUtc)
        .orderBy('created_at', descending: false)
        .get();

    final sales = <Map<String, dynamic>>[];
    final lines = <Map<String, dynamic>>[];

    for (final d in qs.docs) {
      final m = d.data();
      final id = d.id;

      final createdAt = (m['created_at'] as Timestamp?)?.toDate();
      final eff = effectiveTimeLocal(m);

      // لو حابب تستبعد الأجل غير المدفوع من التصدير، فكّ الكومنت:
      // final isDeferred = (m['is_deferred'] ?? false) == true;
      // final paid = (m['paid'] ?? (!isDeferred)) == true;
      // if (isDeferred && !paid) continue;

      sales.add({
        'id': id,
        'created_at': _fmtDateTimeLocal(createdAt),
        'effective_time': _fmtDateTimeLocal(eff),
        'settled_at': _fmtDateTimeLocal(
          (m['settled_at'] as Timestamp?)?.toDate(),
        ),
        'type': _safeStr(m['type']),
        'name': _safeStr(m['name'] ?? m['drink_name']),
        'variant': _safeStr(m['variant'] ?? m['roast']),
        'grams': _numD(m['grams'] ?? m['total_grams']),
        'quantity': _numD(m['quantity']),
        'total_price': _numD(m['total_price']),
        'total_cost': _numD(m['total_cost']),
        'profit_total': _numD(m['profit_total']),
        'is_deferred': (m['is_deferred'] ?? false) == true,
        'paid': (m['paid'] ?? false) == true,
        'due_amount': _numD(m['due_amount']),
        'is_spiced': (m['is_spiced'] ?? false) == true,
        'spice_amount': _numD(m['spice_amount']),
        'notes': _safeStr(m['notes']),
      });

      lines.addAll(_extractLines(id, m));
    }

    final bytes = _buildExcelBytes(sales: sales, lines: lines);

    final fileName =
        'sales_${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}__'
        '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';

    // حفظ مباشر في Downloads — بدون اختيار مجلد (يمنع "Dialog was null")
    final savedPath = await FileSaver.instance.saveFile(
      name: fileName,
      ext: 'xlsx',
      bytes: bytes,
      mimeType: MimeType.microsoftExcel,
    );

    if (context.mounted) Navigator.pop(context); // قفل اللودينج

    // SnackBar طويل + زر فتح
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 14),
          content: Text(
            'تم الحفظ في التنزيلات: $savedPath',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: 'فتح',
            onPressed: () async {
              try {
                await OpenFilex.open(savedPath);
              } catch (_) {}
            },
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context); // قفل اللودينج
    // بديل: مشاركة الملف لو فشل الحفظ
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تعذّر الحفظ في التنزيلات. هشارك الملف بدلًا من ذلك. ($e)',
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }
}

// إعادة استخدام: تاريخ/وقت من أي نوع
DateTime _asLocal(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.tryParse(v?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// وقت العرض الفعّال:
/// - أجل غير مدفوع ⇒ اليوم الحالي 05:00 (محلي)
/// - مدفوع + settled_at ⇒ settled_at
/// - غير ذلك ⇒ created_at

/// مفتاح يوم التشغيل: Shift -4h → yyyy-MM-dd
String opDayKeyFromLocal(DateTime t) {
  final s = t.subtract(const Duration(hours: 4));
  return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
}

/// مجموع المبيعات لليوم مع استبعاد الضيافة + الأجل غير المدفوع
double sumPaidNonComplOnly(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
) {
  double s = 0;
  for (final e in es) {
    final m = e.data();
    final isCompl = (m['is_complimentary'] ?? false) == true;
    final isDeferred = (m['is_deferred'] ?? m['is_credit'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    if (!isCompl && paid) s += numD(m['total_price']);
  }
  return s;
}

/// هل التاريخ داخل المدى [start, end)

bool isUnpaidDeferredMap(Map<String, dynamic> m) =>
    (m['is_deferred'] ?? false) == true && (m['paid'] ?? false) == false;

/// يجمع حقل معين للعمليات المدفوعة فقط (يستثني الأجل غير المدفوع)
double sumFieldPaidOnly(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
  String k,
) {
  double s = 0;
  for (final e in es) {
    final m = e.data();
    if (isUnpaidDeferredMap(m)) continue; // استثناء الأجل غير المدفوع
    final v = m[k];
    if (v is num) {
      s += v.toDouble();
    } else {
      s += double.tryParse('${v ?? 0}') ?? 0.0;
    }
  }
  return s;
}
