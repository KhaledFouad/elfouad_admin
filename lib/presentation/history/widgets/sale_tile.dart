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
        DateTime.tryParse(m['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    double _num(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;

    final detectedType = detectType(m);
    final type = (m['type'] ?? detectedType).toString();

    final isCompl = (m['is_complimentary'] ?? false) == true;
    final isDeferred = (m['is_deferred'] ?? false) == true;
    final paid = (m['paid'] ?? (!isDeferred)) == true;
    final dueAmount = _num(m['due_amount']);

    final totalPrice = numD(m['total_price']);
    final totalCost = numD(m['total_cost']);
    final profitFromDoc = numD(m['profit_total']);

    // عرض الربح:
    // - ضيافة => 0
    // - أجل ولسه متدفعش => 0
    // - غير كده => profit_total إن وُجد وإلا (السعر - التكلفة)
    final displayedProfit = (isCompl || (isDeferred && !paid))
        ? 0.0
        : (profitFromDoc != 0 ? profitFromDoc : (totalPrice - totalCost));

    final components = extractComponents(m, type);

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.brown.shade100,
        child: Icon(
          iconForType(type),
          color: const Color.fromRGBO(93, 64, 55, 1),
          size: 18,
        ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text('ضيافة', style: TextStyle(fontSize: 11)),
            ),
          ],
          if (isDeferred && !paid) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text('أجل', style: TextStyle(fontSize: 11)),
            ),
          ],
          if (isDeferred && paid) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text('مدفوع', style: TextStyle(fontSize: 11)),
            ),
          ],
          const SizedBox(width: 6),
          Text(
            fmtTime(createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          kv('الإجمالي', totalPrice),
          kv('التكلفة', totalCost),
          kv('الربح', displayedProfit),
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
        if (components.isEmpty)
          const ListTile(title: Text('— لا توجد تفاصيل مكونات —'))
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: components
                  .map((c) => componentRowWithSettle(c, m, context, doc.id))
                  .toList(),
            ),
          ),
        deferredSettleButton(
          context: context,
          docId: doc.id,
          isDeferred: isDeferred,
          paid: paid,
          dueAmount: dueAmount,
        ),
      ],
    );
  }
}
