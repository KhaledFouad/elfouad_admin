import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'sale_tile.dart';

class DaySection extends StatelessWidget {
  final String day;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> entries;
  final double sumPrice, sumCost, sumProfit;
  final int cups;
  final double grams;
  final int extrasPieces;
  final int saleCount;
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
    required this.extrasPieces,
    required this.saleCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                  _pill(
                    Icons.receipt_long,
                    AppStrings.operationsCountLabel,
                    saleCount,
                    suffix: AppStrings.operationSuffix,
                    decimals: 0,
                  ),
                  _pill(Icons.attach_money, AppStrings.salesLabel, sumPrice),
                  _pill(Icons.factory, AppStrings.costLabel, sumCost),
                  _pill(Icons.trending_up, AppStrings.profitLabel, sumProfit),
                  _pill(Icons.local_cafe, AppStrings.drinksLabel, cups),
                  _pill(Icons.scale, AppStrings.gramsCoffeeLabel, grams),
                  if (extrasPieces > 0)
                    _pill(Icons.cookie_outlined, AppStrings.snacksLabel, extrasPieces),
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

  static Widget _pill(
    IconData icon,
    String label,
    num v, {
    String? suffix,
    int? decimals,
  }) {
    final isGrams = label.contains(AppStrings.gramsKeyword) ||
        label.contains(AppStrings.gramsShortKeyword);
    final isPieces =
        label.contains(AppStrings.maamoulKeyword) ||
        label.contains(AppStrings.datesKeyword) ||
        label.contains(AppStrings.snacksLabel) ||
        label.contains(AppStrings.countKeyword);
    final fraction =
        decimals ?? ((isGrams || isPieces || v is int) ? 0 : 2);
    final valueText = v.toStringAsFixed(fraction);
    final text =
        (suffix == null || suffix.isEmpty) ? valueText : '$valueText $suffix';
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
