import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:responsive_framework/responsive_framework.dart';

class RecipePrepLogPage extends StatelessWidget {
  const RecipePrepLogPage({super.key});

  double _numOf(dynamic v, [double def = 0.0]) {
    if (v is num) return v.toDouble();
    final raw = '${v ?? ''}'.replaceAll(',', '.').trim();
    return double.tryParse(raw) ?? def;
  }

  int _intOf(dynamic v, [int def = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? def;
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

  @override
  Widget build(BuildContext context) {
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final contentMaxWidth = breakpoints.largerThan(TABLET)
        ? 1100.0
        : double.infinity;
    final horizontalPadding = isPhone ? 12.0 : 16.0;

    final stream = FirebaseFirestore.instance
        .collection('recipe_preps')
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              centerTitle: true,
              title: const Text(
                AppStrings.recipePrepLogTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5D4037), Color(0xFF795548)],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      AppStrings.loadFailedSimple(
                        snapshot.error ?? 'unknown',
                      ),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text(AppStrings.noItems));
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    24,
                  ),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildPrepCard(context, docs[index]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrepCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = (data['name'] ?? AppStrings.unnamedLabel).toString();
    final variant = (data['variant'] ?? '').toString();
    final title = variant.isEmpty ? name : '$name - $variant';
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();
    final dateLabel = createdAt == null
        ? '--'
        : intl.DateFormat('yyyy/MM/dd - HH:mm').format(createdAt);
    final amountKg = _numOf(data['amount_kg']);
    final amountGrams = _intOf(data['amount_grams']);
    final totalGrams = amountGrams > 0
        ? amountGrams
        : (amountKg > 0 ? (amountKg * 1000).round() : 0);
    final components = _asListMap(data['components']);

    return InkWell(
      onTap: () => _openPrepDetails(context, doc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.brown.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _valueChip(
                    AppStrings.kgAmountShortLabel,
                    amountKg.toStringAsFixed(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _valueChip(
                    AppStrings.gramsLabel,
                    totalGrams.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.componentsCount(components.length),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _openPrepDetails(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = (data['name'] ?? AppStrings.unnamedLabel).toString();
    final variant = (data['variant'] ?? '').toString();
    final title = variant.isEmpty ? name : '$name - $variant';
    final createdAt = (data['created_at'] as Timestamp?)?.toDate();
    final dateLabel = createdAt == null
        ? '--'
        : intl.DateFormat('yyyy/MM/dd - HH:mm').format(createdAt);
    final amountKg = _numOf(data['amount_kg']);
    final amountGrams = _intOf(data['amount_grams']);
    final totalGrams = amountGrams > 0
        ? amountGrams
        : (amountKg > 0 ? (amountKg * 1000).round() : 0);
    final components = _asListMap(data['components']);
    final recipeId = (data['recipe_id'] ?? '').toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const Text(
                    AppStrings.recipePrepDetailsTitle,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _detailRow(
                          AppStrings.kgAmountShortLabel,
                          amountKg.toStringAsFixed(2),
                        ),
                        _detailRow(
                          AppStrings.gramsLabel,
                          totalGrams.toString(),
                        ),
                        if (recipeId.isNotEmpty)
                          _detailRow(
                            AppStrings.recipeIdLabel,
                            recipeId,
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          AppStrings.componentsLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (components.isEmpty)
                          const Text(AppStrings.noItems)
                        else
                          ...components.map((c) {
                            final cName = (c['name'] ?? '').toString();
                            final cVariant = (c['variant'] ?? '').toString();
                            final cPercent = _numOf(c['percent']);
                            final grams = totalGrams > 0
                                ? (totalGrams * (cPercent / 100)).round()
                                : 0;
                            final meta = <String>[];
                            final coll = (c['coll'] ?? '').toString();
                            final itemId = (c['item_id'] ?? c['itemId'] ?? '')
                                .toString();
                            if (coll.isNotEmpty) meta.add(coll);
                            if (itemId.isNotEmpty) meta.add(itemId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.brown.shade50.withValues(
                                  alpha: 140,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    AppStrings.componentPercentLine(
                                      cName,
                                      cVariant,
                                      cPercent,
                                      grams,
                                    ),
                                  ),
                                  if (meta.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      meta.join(' - '),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.black54),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
