import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:elfouad_admin/presentation/recipes/recipes_component.dart';
import 'package:elfouad_admin/presentation/recipes/recipe_edit_sheet.dart';
import 'package:elfouad_admin/presentation/recipes/recipe_prepare_sheet.dart';
// لو أنت مستعمل اسم مختلف لورقة التحضير (prepare_batch_sheet) بدّل السطر اللي فوق بالاستيراد الصحيح.

class RecipesListPage extends StatelessWidget {
  const RecipesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('recipes')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('تعذّر التحميل: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد توليفات بعد'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemBuilder: (ctx, i) => _RecipeTile(doc: docs[i]),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: docs.length,
          );
        },
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _RecipeTile({required this.doc});

  List<RecipeComponent> _readComponents(Map<String, dynamic> m) {
    final rows = (m['components'] as List? ?? const [])
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .map(RecipeComponent.fromMap)
        .toList();
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final name = (m['name'] ?? '').toString();
    final comps = _readComponents(m);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0.5,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
          childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
          title: Text(
            name.isEmpty ? 'توليفة بدون اسم' : name,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          subtitle: Text('اضغط لعرض التفاصيل'),
          trailing: const Icon(Icons.expand_more),

          // Expanded content:
          children: [
            // المكونات بالنِّسَب
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comps.map((c) {
                  final title = c.variant.isEmpty
                      ? c.name
                      : '${c.name} — ${c.variant}';
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 4),
                    child: Text('• $title  (%${c.percent.toStringAsFixed(1)})'),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // حساب سعر/تكلفة/كجم
            FutureBuilder<_RecipeMetrics>(
              future: _RecipeMetrics.compute(comps),
              builder: (ctx, ss) {
                if (ss.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                if (ss.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('تعذر الحساب: ${ss.error}'),
                  );
                }
                final m = ss.data!;
                return Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _pill(Icons.sell, 'سعر/كجم', m.pricePerKg),
                    _pill(Icons.factory, 'تكلفة/كجم', m.costPerKg),
                    _pill(
                      Icons.trending_up,
                      'ربح/كجم',
                      (m.pricePerKg - m.costPerKg),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 10),
            // أزرار الإجراءات
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.scale),
                    label: const Text('تحضير التوليفة'),
                    onPressed: () => _openPrepare(context, doc.id, comps),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _openEdit(context, doc.id),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, doc.id, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _pill(IconData i, String k, double v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 16),
          const SizedBox(width: 6),
          Text(
            '$k: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Text(
            v.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, String id) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => RecipeEditSheet(recipeId: id),
    );
  }

  Future<void> _openPrepare(
    BuildContext context,
    String id,
    List<RecipeComponent> comps,
  ) async {
    // بدّل الـ widget لو كان اسم ورقة التحضير عندك مختلف
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => RecipePrepareSheet(recipeId: id),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String id,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف التوليفة'),
        content: Text('هل تريد حذف "${name.isEmpty ? 'توليفة' : name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('recipes').doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحذف')));
      }
    }
  }
}

/// حساب سريع لسعر/تكلفة/كجم من المخزون حسب النِّسَب
class _RecipeMetrics {
  final double pricePerKg;
  final double costPerKg;
  _RecipeMetrics(this.pricePerKg, this.costPerKg);

  static Future<_RecipeMetrics> compute(List<RecipeComponent> comps) async {
    double p = 0, c = 0;
    final fs = FirebaseFirestore.instance;

    // اجمع بالتوازي
    final futures = comps.map((rc) async {
      final coll = rc.coll; // 'singles' | 'blends'
      final snap = await fs.collection(coll).doc(rc.itemId).get();
      final m = snap.data() ?? const <String, dynamic>{};
      final sellPerKg = (m['sellPricePerKg'] as num?)?.toDouble() ?? 0.0;
      final costPerKg = (m['costPricePerKg'] as num?)?.toDouble() ?? 0.0;
      final w = (rc.percent.isNaN ? 0.0 : rc.percent) / 100.0;
      p += w * sellPerKg;
      c += w * costPerKg;
    }).toList();

    await Future.wait(futures);
    return _RecipeMetrics(p, c);
  }
}
