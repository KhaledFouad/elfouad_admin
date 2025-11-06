import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/sales_history_utils.dart';

class SaleTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SaleTile({
    super.key,
    required this.doc,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final createdAt =
        (m['created_at'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final detectedType = detectType(m);
    final type = (m['type'] ?? detectedType).toString();

    final isCompl = (m['is_complimentary'] ?? false) == true;
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    final dueAmount = numD(m['due_amount']);

    final totalPrice = numD(m['total_price']);
    final totalCost = numD(m['total_cost']);
    final profit = numD(m['profit_total']);

    final components = extractComponents(m, type);
    final eff = effectiveTimeLocal(m);

    // الملاحظة (note/notes)
    final String note = ((m['note'] ?? m['notes'] ?? '') as Object)
        .toString()
        .trim();

    // أيقونة محلية لو النوع extra، وإلا استخدم الموجودة في utils
    final icon = type == 'extra' ? Icons.cookie_outlined : iconForType(type);

    // 👇 تفاصيل افتراضية لعمليات المعمول/التمر لو مفيش components
    List<Map<String, dynamic>> componentsToShow = components;
    if (componentsToShow.isEmpty && type == 'extra') {
      final name = (m['name'] ?? '').toString();
      final variant = (m['variant'] ?? '').toString();
      final unit = (m['unit'] ?? 'piece').toString();
      final qty = (m['quantity'] is num)
          ? (m['quantity'] as num).toInt()
          : int.tryParse('${m['quantity'] ?? 0}') ?? 0;

      componentsToShow = [
        {
          'name': name,
          'variant': variant,
          'unit': unit,
          'qty': qty,
          'grams': 0, // مش بنستخدم جرامات هنا
          'line_total_price': totalPrice, // إجمالي العملية
          'line_total_cost': totalCost, // إجمالي العملية
        },
      ];
    }

    return ExpansionTile(
      key: PageStorageKey(doc.id),
      maintainState: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.brown.shade100,
        child: Icon(icon, color: const Color.fromRGBO(93, 64, 55, 1), size: 18),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              titleLine(m, type),
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCompl) ...[
            const SizedBox(width: 6),
            _chip('ضيافة', Colors.orange.shade200, Colors.orange.shade50),
          ],
          if (isDeferred && !paid) ...[
            const SizedBox(width: 6),
            _chip('أجل', Colors.red.shade200, Colors.red.shade50),
          ],
          if (isDeferred && paid) ...[
            const SizedBox(width: 6),
            _chip('مدفوع', Colors.green.shade200, Colors.green.shade50),
          ],
          const SizedBox(width: 6),
          Text(
            fmtTime(eff),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _kv('الإجمالي', totalPrice),
          _kv('التكلفة', totalCost),
          _kv('الربح', profit),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تعديل',
                onPressed: onEdit,
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
      children: [
        if (componentsToShow.isEmpty)
          const ListTile(title: Text('— لا توجد تفاصيل مكونات —'))
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: componentsToShow.map(componentRow).toList(),
            ),
          ),

        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 18,
                  color: Colors.brown,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (!_sameMinute(eff, createdAt))
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 8,
            ),
            child: Row(
              children: const [
                Icon(Icons.history, size: 16, color: Colors.brown),
                SizedBox(width: 6),
              ],
            ),
          ),
        if (!_sameMinute(eff, createdAt))
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 40,
              end: 16,
              bottom: 12,
            ),
            child: Text(
              'التاريخ الأصلي: ${_fmtDateTime(createdAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        if (isDeferred && !paid && dueAmount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                    const Color(0xFF543824),
                  ),
                ),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('تأكيد السداد'),
                      content: Text(
                        'سيتم تثبيت دفع ${totalPrice.toStringAsFixed(2)} جم.\nهل تريد المتابعة؟',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('تأكيد'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    try {
                      await settleDeferredSale(doc.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تسوية العملية المؤجّلة'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر التسوية: $e')),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.payments),
                label: const Text('تم الدفع'),
              ),
            ),
          ),
      ],
    );
  }

  static Widget _chip(String label, Color border, Color fill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  static bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  static String _fmtDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $h:$mm';
  }
}

Widget _kv(String k, double v) {
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

/// عنوان السطر – حالة extras مخصّصة للمعمول/التمر
String titleLine(Map<String, dynamic> m, String type) {
  String name = (m['name'] ?? '').toString();
  String variant = (m['variant'] ?? m['roast'] ?? '').toString();
  String labelNV = variant.isNotEmpty ? '$name $variant' : name;

  switch (type) {
    case 'extra':
      final q = (m['quantity'] is num)
          ? (m['quantity'] as num).toInt()
          : int.tryParse('${m['quantity'] ?? 0}') ?? 0;
      final lbl = labelNV.isNotEmpty ? labelNV : name;
      return 'سناكس - $q ${lbl.isNotEmpty ? lbl : ''}'.trim();

    case 'drink':
      final qd = numD(m['quantity']) > 0
          ? numD(m['quantity']).toStringAsFixed(0)
          : '1';
      final dn = (m['drink_name'] ?? '').toString();
      final finalName = labelNV.isNotEmpty
          ? labelNV
          : (dn.isNotEmpty ? dn : 'مشروب');
      return 'مشروب - $qd $finalName';

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
      return labelNV.isNotEmpty ? labelNV : 'عملية';
  }
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
