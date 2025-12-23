import 'package:awesome_drawer_bar/awesome_drawer_bar.dart'
    show AwesomeDrawerBar;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:flutter/material.dart';

import 'recipe_edit_sheet.dart';
import 'recipe_prepare_sheet.dart';
import 'recipes_component.dart';

class RecipesListPage extends StatefulWidget {
  const RecipesListPage({super.key});

  @override
  State<RecipesListPage> createState() => _RecipesListPageState();
}

class _RecipesListPageState extends State<RecipesListPage> {
  Stream<QuerySnapshot<Map<String, dynamic>>> _recipesStream() {
    return FirebaseFirestore.instance
        .collection('recipes')
        .orderBy('name')
        .snapshots();
  }

  // يحسب سعر/تكلفة الكيلو بالتجميع المرجّح حسب نسب المكونات
  Future<_PriceCost> _calcPriceCost(Map<String, dynamic> recipe) async {
    final fs = FirebaseFirestore.instance;
    final comps = ((recipe['components'] ?? []) as List)
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .map(RecipeComponent.fromMap)
        .toList();

    double pricePerKg = 0.0;
    double costPerKg = 0.0;

    for (final c in comps) {
      final snap = await fs.collection(c.coll).doc(c.itemId).get();
      final m = snap.data() ?? {};

      // في داتا قديمة ممكن يبقى اسم الحقول مختلف
      double numOf(keys) {
        for (final k in keys) {
          final v = m[k];
          if (v is num) return v.toDouble();
        }
        return 0.0;
      }

      final sell = numOf(['sellPricePerKg', 'sellPerKg', 'sell_price_per_kg']);
      final cost = numOf(['costPricePerKg', 'costPerKg', 'cost_price_per_kg']);

      pricePerKg += sell * (c.percent / 100.0);
      costPerKg += cost * (c.percent / 100.0);
    }
    return _PriceCost(pricePerKg: pricePerKg, costPerKg: costPerKg);
  }

  int _sumPercent(List<RecipeComponent> cs) =>
      cs.fold(0, (s, c) => s + (c.percent.isNaN ? 0 : c.percent.round()));

  Future<void> _deleteRecipe(String id, String displayName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.deleteRecipeTitle),
        content: Text(AppStrings.deleteRecipeConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance.collection('recipes').doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.recipeDeleted(displayName))));
  }

  void _openEdit([String? recipeId]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RecipeEditSheet(recipeId: recipeId),
      ),
    );
  }

  void _openPrepare(String recipeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RecipePrepareSheet(recipeId: recipeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => AwesomeDrawerBar.of(context)?.toggle(),
              ),
              title: const Text(
                AppStrings.recipesTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 35,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 8,
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEdit(),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.newRecipeTitle),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _recipesStream(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return Center(child: Text(AppStrings.loadFailedSimple(s.error!)));
            }

            final docs = s.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text(AppStrings.noRecipesYet));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = docs[i];
                final m = d.data();
                final name = (m['name'] ?? '').toString();
                final variant = (m['variant'] ?? '').toString();
                final comps = ((m['components'] ?? []) as List)
                    .map(
                      (e) => (e is Map)
                          ? e.cast<String, dynamic>()
                          : <String, dynamic>{},
                    )
                    .map(RecipeComponent.fromMap)
                    .toList();
                final sum = _sumPercent(comps);

                final title = variant.isEmpty ? name : '$name — $variant';

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.brown.shade100),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 8,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    title: Text(
                      title.isEmpty ? AppStrings.unnamedLabel : title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      AppStrings.componentsCount(comps.length),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: sum == 100 ? Colors.green : Colors.red,
                      ),
                    ),
                    children: [
                      // تفاصيل المكونات
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: comps.map((c) {
                            final t = c.variant.isEmpty
                                ? c.name
                                : '${c.name} — ${c.variant}';
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('• '),
                                Text(
                                  AppStrings.componentPercentSummary(
                                    t,
                                    c.percent,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // السعر/التكلفة (FutureBuilder)
                      FutureBuilder<_PriceCost>(
                        future: _calcPriceCost(m),
                        builder: (ctx, ps) {
                          if (ps.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: LinearProgressIndicator(minHeight: 2),
                            );
                          }
                          final pc =
                              ps.data ??
                              const _PriceCost(pricePerKg: 0, costPerKg: 0);
                          return Row(
                            children: [
                              const Icon(Icons.payments_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.pricePerKgInline(pc.pricePerKg),
                              ),
                              const SizedBox(width: 18),
                              const Icon(Icons.calculate_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.costPerKgInline(pc.costPerKg),
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
                              icon: const Icon(Icons.scale_outlined),
                              label: const Text(AppStrings.prepareBlendLabel),
                              onPressed: () => _openPrepare(d.id),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: AppStrings.actionEdit,
                            icon: const Icon(Icons.edit),
                            onPressed: () => _openEdit(d.id),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            tooltip: AppStrings.actionDelete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteRecipe(d.id, title),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PriceCost {
  final double pricePerKg;
  final double costPerKg;
  const _PriceCost({required this.pricePerKg, required this.costPerKg});
}
