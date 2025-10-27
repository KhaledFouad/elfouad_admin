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

const int kOpShiftHours = 4;

// مثال استخدام:
String opDayKeyFromLocal(DateTime t) => (() {
  final s = t.subtract(Duration(hours: kOpShiftHours));
  return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
})();

DateTime opRolloverLocalToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, kOpShiftHours);
}

DateTime viewCreatedAtFor(Map<String, dynamic> m) {
  final origUtc = createdAtUtcOf(m); // UTC من الداتابيز
  if (!isUnpaidDeferredMap(m)) return origUtc;

  final anchorLocal = opAnchorForNowLocal(); // 04:00 اليوم/أمس (محلي)
  final anchorUtc = anchorLocal.toUtc();

  final origKey = opDayKeyFromLocal(origUtc.toLocal());
  final anchorKey = opDayKeyFromLocal(anchorLocal);

  // نرحّل فقط لو الأقدم من المرساة
  return (origKey.compareTo(anchorKey) < 0) ? anchorUtc : origUtc;
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
  final anchorLocal = opAnchorForNowLocal();
  final anchorKey = opDayKeyFromLocal(anchorLocal);

  final byDay = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

  for (final d in docs) {
    final m = d.data();
    final origLocal = createdAtUtcOf(m).toLocal();
    String key = opDayKeyFromLocal(origLocal);

    if (isUnpaidDeferredMap(m) && key.compareTo(anchorKey) < 0) {
      // نرحّل للأيام الأقدم إلى مفتاح المرساة الحالي
      key = anchorKey;
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
      if (!data.containsKey('original_created_at'))
        'original_created_at': oldCreated,
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

// يبدأ يوم التشغيل 04:00

/// 04:00 من يوم التاريخ الممرر
DateTime opStartOfDayLocal(DateTime d) =>
    DateTime(d.year, d.month, d.day, kOpShiftHours);

/// المرساة الحالية ليوم التشغيل:
/// - قبل 04:00 → ترجع 04:00 بتاعة "أمس"
/// - 04:00 فما بعد → ترجع 04:00 بتاعة "اليوم"
DateTime opAnchorForNowLocal() {
  final now = DateTime.now();
  final startToday = opStartOfDayLocal(now);
  return now.isBefore(startToday)
      ? startToday.subtract(const Duration(days: 1))
      : startToday;
}

/// مفتاح يوم التشغيل (shift -4h)

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
    // مرساة اليوم التشغيلي الحالية (04:00 اليوم أو 04:00 أمس حسب الوقت)
    final anchor = opAnchorForNowLocal();
    // لا ننقل إلا لو يوم العملية أقدم من المرساة
    final origKey = opDayKeyFromLocal(createdAt);
    final anchorKey = opDayKeyFromLocal(anchor);
    return (origKey.compareTo(anchorKey) < 0) ? anchor : createdAt;
  }

  if (paid && settledAt != null) return settledAt;
  return createdAt;
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
// ========= ADD THIS TO utils/sales_history_utils.dart =========

double _dNum(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}

/// اجمع جرامات البيع لكل صنف (singles/blends) من مستند عملية بيع
Map<DocumentReference<Map<String, dynamic>>, double> stockOpsFromSale(
  Map<String, dynamic> m,
) {
  final db = FirebaseFirestore.instance;
  final out = <DocumentReference<Map<String, dynamic>>, double>{};
  void acc(String? coll, dynamic id, double grams) {
    if (coll == null || id == null || grams <= 0) return;
    final ref = db.collection(coll).doc(id.toString());
    out[ref] = (out[ref] ?? 0.0) + grams;
  }

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

  final type = '${m['type'] ?? ''}';
  if (type == 'single' || type == 'ready_blend') {
    final coll = type == 'single' ? 'singles' : 'blends';
    final id = m['single_id'] ?? m['blend_id'] ?? m['item_id'] ?? m['id'];
    acc(coll, id, _dNum(m['grams']));
    return out;
  }

  if (type == 'custom_blend') {
    final rows = [
      ...asList(m['components']),
      ...asList(m['items']),
      ...asList(m['lines']),
    ];
    for (final r in rows) {
      final grams = _dNum(r['grams']);
      String? coll = (r['coll'] ?? r['collection'])?.toString();
      dynamic id = r['id'] ?? r['item_id'] ?? r['single_id'] ?? r['blend_id'];
      coll ??= (r['blend_id'] != null)
          ? 'blends'
          : (r['single_id'] != null)
          ? 'singles'
          : null;
      acc(coll, id, grams);
    }
  }

  return out; // drinks/unknown => مفيش تأثير
}

/// تعديل بيع: طبّق فرق المخزون Old vs New داخل Transaction + حدّث المستند.
Future<void> applyStockDeltaOnSaleEdit(
  DocumentReference<Map<String, dynamic>> saleRef,
  Map<String, dynamic> updates,
) async {
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final oldSnap = await tx.get(saleRef);
    final oldSale = oldSnap.data() ?? <String, dynamic>{};
    final newSale = {...oldSale, ...updates};

    final oldOps = stockOpsFromSale(oldSale);
    final newOps = stockOpsFromSale(newSale);

    final refs = {...oldOps.keys, ...newOps.keys};
    for (final r in refs) {
      final oldG = oldOps[r] ?? 0.0;
      final newG = newOps[r] ?? 0.0;
      final diff = newG - oldG; // + يعني هننقص من المخزون، - يعني هنزود
      if (diff.abs() > 0.0001) {
        tx.update(r, {'stock': FieldValue.increment(-diff)});
      }
    }

    tx.update(saleRef, updates);
  });
}

/// حذف بيع: رجّع المخزون (إضافة راجعة) داخل Transaction ثم احذف المستند.
Future<void> deleteSaleWithStockRollback(
  DocumentReference<Map<String, dynamic>> saleRef,
) async {
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(saleRef);
    if (!snap.exists) return;
    final m = snap.data() ?? <String, dynamic>{};
    final ops = stockOpsFromSale(m);

    // رجوع كامل الجرامات التي كانت متباعة
    for (final r in ops.keys) {
      final grams = ops[r] ?? 0.0;
      if (grams > 0) {
        tx.update(r, {'stock': FieldValue.increment(grams)});
      }
    }

    tx.delete(saleRef);
  });
}

/// جلب معدّلات التحويج (سعر/تكلفة للكيلو) من الداتا.
/// الأولوية: Doc الصنف (singles/blends) -> إعدادات عامة settings/spice -> 0

/// يرجّع (pricePerKg, costPerKg) للتحويج.
/// الأولويات: Doc الصنف -> settings/spice -> fallback حسب الاسم.
/// NOTE: لو cost مش موجود هندي fallback = 50% من السعر كرقم تقريبي (عدّله لو عندك سياسة مختلفة).
Future<({double pricePerKg, double costPerKg})> fetchSpiceRatesForSale(
  Map<String, dynamic> sale,
) async {
  final db = FirebaseFirestore.instance;
  double price = 0.0;
  double cost = 0.0;

  // حدّد المجموعة والـ id
  String type = '${sale['type'] ?? ''}';
  String? coll;
  String? id =
      sale['single_id']?.toString() ??
      sale['blend_id']?.toString() ??
      sale['item_id']?.toString() ??
      sale['id']?.toString();

  if (type == 'single' ||
      sale.containsKey('single_id') ||
      sale['lines_type'] == 'single') {
    coll = 'singles';
  } else if (type == 'ready_blend' ||
      sale.containsKey('blend_id') ||
      sale['lines_type'] == 'ready_blend') {
    coll = 'blends';
  }

  // (1) جرّب من Doc الصنف
  if (coll != null && id != null) {
    try {
      final doc = await db.collection(coll).doc(id).get();
      final m = doc.data();
      if (m != null) {
        price = _numOf(m['spicePricePerKg'] ?? m['spice_price_per_kg']);
        cost = _numOf(m['spiceCostPerKg'] ?? m['spice_cost_per_kg']);
      }
    } catch (_) {}
  }

  // (2) جرّب من settings/spice
  if (price <= 0 || cost <= 0) {
    try {
      final s = await db.collection('settings').doc('spice').get();
      final m = s.data();
      if (m != null) {
        if (price <= 0) price = _numOf(m['price_per_kg']);
        if (cost <= 0) cost = _numOf(m['cost_per_kg']);
      }
    } catch (_) {}
  }

  // (3) Fallback حسب الاسم
  if (price <= 0) {
    final name =
        (sale['name'] ??
                sale['single_name'] ??
                sale['blend_name'] ??
                sale['product_name'] ??
                '')
            .toString();
    price = spiceRatePerKgForSingle(name);
  }

  // تكلفة احتياطية: لو لسه 0 خلّيها 50% من السعر (غيّره لو عايز)
  if (cost <= 0 && price > 0) cost = (price * 0.5);

  return (pricePerKg: price, costPerKg: cost);
}

// Helper: parse number safely
double _numOf(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}
