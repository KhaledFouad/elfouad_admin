import 'package:awesome_drawer_bar/awesome_drawer_bar.dart'
    show AwesomeDrawerBar;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/inventory/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recipe_edit_sheet.dart';
import 'prepare_batch_sheet.dart';

class RecipesPage extends ConsumerWidget {
  static const route = '/recipes';
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final singles = ref.watch(singlesStreamProvider);
    final blends = ref.watch(blendsStreamProvider);

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
                " تحضير التوليفات",
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
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('recipes')
              .orderBy('created_at', descending: true)
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Center(child: Text('تعذّر التحميل: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // فهارس الأصناف لقراءة السعر/التكلفة
            final singlesMap = singles.maybeWhen(
              data: (rows) => {for (final r in rows) r.id: r},
              orElse: () => <String, InventoryRow>{},
            );
            final blendsMap = blends.maybeWhen(
              data: (rows) => {for (final r in rows) r.id: r},
              orElse: () => <String, InventoryRow>{},
            );

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('لا توجد توليفات بعد'));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i];
                final m = d.data();
                final name = (m['name'] ?? '').toString();
                final comps = (m['components'] as List? ?? const [])
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList();

                // حساب سعر/تكلفة/ربح لكل كجم
                double pricePerKg = 0, costPerKg = 0;
                for (final c in comps) {
                  final coll = (c['coll'] ?? '').toString(); // singles | blends
                  final id = (c['itemId'] ?? c['id'] ?? '').toString();
                  final p = ((c['percent'] ?? 0) as num).toDouble();
                  final row = coll == 'singles'
                      ? singlesMap[id]
                      : (coll == 'blends' ? blendsMap[id] : null);
                  if (row != null) {
                    pricePerKg += (p / 100.0) * row.sellPerKg;
                    costPerKg += (p / 100.0) * row.costPerKg;
                  }
                }
                final profitPerKg = pricePerKg - costPerKg;

                return Card(
                  child: ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          comps
                              .map((c) {
                                final n = (c['name'] ?? '').toString();
                                final v = (c['variant'] ?? '').toString();
                                final p = (c['percent'] ?? 0).toString();
                                return '${v.isEmpty ? n : '$n — $v'} ($p%)';
                              })
                              .join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'سعر/كجم: ${pricePerKg.toStringAsFixed(2)}   •   '
                          'تكلفة/كجم: ${costPerKg.toStringAsFixed(2)}   •   '
                          'ربح/كجم: ${profitPerKg.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تحضير كمية',
                          icon: const Icon(Icons.scale),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                            ),
                            builder: (_) => PrepareBatchSheet(recipeSnap: d),
                          ),
                        ),
                        IconButton(
                          tooltip: 'تعديل',
                          icon: const Icon(Icons.edit),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                            ),
                            builder: (_) => RecipeEditSheet(recipeId: d.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (_) => const RecipeEditSheet(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('توليفة جديدة'),
        ),
      ),
    );
  }
}
