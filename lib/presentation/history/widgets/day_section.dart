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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // سطر اليوم لوحده عشان ما يزاحمش الكبسولات
            Text(
              day,
              textAlign: TextAlign.start, // في RTL هتبقى ناحية اليمين
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            // الكبسولات: Wrap بدل Row علشان ما يحصلش Overflow
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill(Icons.attach_money, 'مبيعات', sumPrice),
                _pill(Icons.factory, 'تكلفة', sumCost),
                _pill(Icons.trending_up, 'ربح', sumProfit),
                _pill(Icons.local_cafe, 'مشروبات', cups.toDouble()),
                _pill(Icons.scale, 'جرام بن', grams),
              ],
            ),

            const Divider(height: 18),

            // العناصر
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
    );
  }

  static Widget _pill(IconData icon, String label, double v) {
    final isGrams = label.contains('جرام');
    final text = isGrams ? '${v.toStringAsFixed(0)} جم' : v.toStringAsFixed(2);

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
          // نتأكد مايحصلش قصّة طول نص
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
