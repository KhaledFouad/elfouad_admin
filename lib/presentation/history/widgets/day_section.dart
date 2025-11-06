import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'sale_tile.dart';

class DaySection extends StatelessWidget {
  final String day;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> entries;
  final double sumPrice, sumCost, sumProfit;
  final int cups;
  final double grams;
  final void Function(DocumentSnapshot<Map<String, dynamic>> doc) onEdit;
  final void Function(DocumentSnapshot<Map<String, dynamic>> doc) onDelete;

  const DaySection({
    super.key,
    required this.day,
    required this.entries,
    required this.sumPrice,
    required this.sumCost,
    required this.sumProfit,
    required this.cups,
    required this.grams,
    required this.onEdit,
    required this.onDelete,
  });

  // اجمع عدد قطع المعمول/التمر من نفس لستة اليوم
  int _extrasPieces() {
    var total = 0;
    for (final e in entries) {
      final m = e.data();
      final t = (m['type'] ?? '').toString();
      if (t == 'extra' ||
          ((m['unit'] ?? '').toString() == 'piece' &&
              m.containsKey('extra_id'))) {
        final q = m['quantity'];
        final qi = (q is num) ? q.toInt() : int.tryParse('${q ?? 0}') ?? 0;
        total += qi;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final extrasPieces = _extrasPieces();

    return RepaintBoundary(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                day,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(Icons.attach_money, 'مبيعات', sumPrice),
                  _pill(Icons.factory, 'تكلفة', sumCost),
                  _pill(Icons.trending_up, 'ربح', sumProfit),
                  _pill(Icons.local_cafe, 'مشروبات', cups),
                  _pill(Icons.scale, 'جرام بن', grams),
                  if (extrasPieces > 0)
                    _pill(Icons.cookie_outlined, 'سناكس', extrasPieces),
                ],
              ),
              const Divider(height: 18),
              ...entries.map(
                (e) => SaleTile(
                  doc: e,
                  onEdit: () => onEdit(e),
                  onDelete: () => onDelete(e),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _pill(IconData icon, String label, dynamic v) {
    final isGrams = label.contains('جرام');
    final isPieces = label.contains('معمول') || label.contains('تمر');
    final text = isGrams
        ? '${v.toStringAsFixed(0)} جم'
        : isPieces
        ? '${v.toStringAsFixed(0)} قطعة'
        : v.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF543824)),
          const SizedBox(width: 6),
          Text(
            '$label: $text',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
