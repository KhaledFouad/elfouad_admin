import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'recipes_component.dart'; // فيه RecipeComponent

class RecipePrepareSheet extends StatefulWidget {
  final String recipeId;
  const RecipePrepareSheet({super.key, required this.recipeId});

  @override
  State<RecipePrepareSheet> createState() => _RecipePrepareSheetState();
}

class _RecipePrepareSheetState extends State<RecipePrepareSheet> {
  final _kgCtrl = TextEditingController(text: '1'); // كمية التحضير بالكيلو
  bool _busy = false;

  @override
  void dispose() {
    _kgCtrl.dispose();
    super.dispose();
  }

  Future<_LoadedRecipe> _load() async {
    final fs = FirebaseFirestore.instance;
    final snap = await fs.collection('recipes').doc(widget.recipeId).get();
    final data = snap.data() ?? {};
    final name = (data['name'] ?? '').toString();
    final comps = ((data['components'] ?? []) as List)
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .map(RecipeComponent.fromMap)
        .toList();

    // هات مخزون كل مكوّن علشان نعرف نكفي ولا لأ
    final withStock = await Future.wait(
      comps.map((c) async {
        final itemSnap = await fs.collection(c.coll).doc(c.itemId).get();
        final m = itemSnap.data() ?? <String, dynamic>{};
        final stock = (m['stock'] as num?)?.toDouble() ?? 0.0; // جرام
        final name = (m['name'] ?? c.name).toString();
        final variant = (m['variant'] ?? c.variant).toString();
        final sellPerKg = (m['sellPricePerKg'] as num?)?.toDouble() ?? 0.0;
        final costPerKg = (m['costPricePerKg'] as num?)?.toDouble() ?? 0.0;
        return _CompState(
          comp: c,
          stockG: stock,
          displayName: variant.isEmpty ? name : '$name — $variant',
          sellPerKg: sellPerKg,
          costPerKg: costPerKg,
        );
      }),
    );

    return _LoadedRecipe(name: name, items: withStock);
  }

  double _parseKg() =>
      double.tryParse(_kgCtrl.text.replaceAll(',', '.')) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FutureBuilder<_LoadedRecipe>(
          future: _load(),
          builder: (ctx, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (s.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('تعذّر تحميل التوليفة: ${s.error}'),
              );
            }
            final r = s.data!;
            final kg = _parseKg();
            final grams = kg * 1000.0;

            // احسب الاحتياج وملخص السعر/التكلفة
            double needOk = 0;
            double pricePerKg = 0, costPerKg = 0;

            final needs = r.items.map((it) {
              final needG = grams * (it.comp.percent / 100.0);
              final ok = it.stockG + 1e-6 >= needG; // يكفي ولا لأ
              if (ok) needOk += 1;
              pricePerKg += (it.sellPerKg) * (it.comp.percent / 100.0);
              costPerKg += (it.costPerKg) * (it.comp.percent / 100.0);
              return _NeedRow(item: it, needG: needG, ok: ok);
            }).toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 42,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Text(
                  'تحضير التوليفة',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  r.name.isEmpty ? 'بدون اسم' : r.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // إدخال كمية بالكيلو
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _kgCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الكمية (كجم)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.brown.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('سعر/كجم: ${pricePerKg.toStringAsFixed(2)}'),
                          Text('تكلفة/كجم: ${costPerKg.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'المكوّنات المطلوبة:',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 6),

                Column(
                  children: needs.map((n) {
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 8,
                        end: 8,
                      ),
                      leading: Icon(
                        n.ok ? Icons.check_circle : Icons.error_outline,
                        color: n.ok ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      title: Text(
                        n.item.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'يحتاج: ${n.needG.toStringAsFixed(0)} جم  •  متاح: ${n.item.stockG.toStringAsFixed(0)} جم',
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.done),
                        label: const Text('تأكيد الخصم من المخزون'),
                        onPressed: (_busy || kg <= 0)
                            ? null
                            : () => _confirmDeduct(r, kg),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeduct(_LoadedRecipe r, double kg) async {
    final fs = FirebaseFirestore.instance;

    // حوّل الكمية المطلوبة لجرامات صحيحة
    int needFor(_CompState it) {
      final need = kg * 1000.0 * (it.comp.percent / 100.0);
      return need.round(); // أعداد صحيحة لتفادي كسور الفلووت
    }

    // تحقق مسبق من الكفاية
    for (final it in r.items) {
      final need = needFor(it);
      final cur = it.stockG.round(); // نتعامل كأعداد صحيحة
      if (cur < need) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('المخزون غير كافٍ لـ "${it.displayName}"')),
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      await fs.runTransaction((tx) async {
        for (final it in r.items) {
          final ref = fs.collection(it.comp.coll).doc(it.comp.itemId);

          // اقرأ القيمة الحالية داخل الترانزاكشن للتأكد مرة تانية
          final snap = await tx.get(ref);
          final cur = ((snap.data()?['stock'] as num?)?.toDouble() ?? 0.0)
              .round();
          final need = needFor(it);

          if (cur < need) {
            throw Exception('نفد المخزون لـ ${it.displayName}');
          }

          // اطرح بالإنكريمنت بأعداد صحيحة
          tx.update(ref, {'stock': FieldValue.increment(-need)});
        }
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الخصم من المخزون')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذّر التحضير: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _LoadedRecipe {
  final String name;
  final List<_CompState> items;
  _LoadedRecipe({required this.name, required this.items});
}

class _CompState {
  final RecipeComponent comp;
  final double stockG;
  final String displayName;
  final double sellPerKg;
  final double costPerKg;
  _CompState({
    required this.comp,
    required this.stockG,
    required this.displayName,
    required this.sellPerKg,
    required this.costPerKg,
  });
}

class _NeedRow {
  final _CompState item;
  final double needG;
  final bool ok;
  _NeedRow({required this.item, required this.needG, required this.ok});
}
