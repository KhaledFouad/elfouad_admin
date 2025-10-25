import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'recipes_component.dart';

class RecipePrepareSheet extends StatefulWidget {
  final String recipeId;
  const RecipePrepareSheet({super.key, required this.recipeId});

  @override
  State<RecipePrepareSheet> createState() => _RecipePrepareSheetState();
}

class _RecipePrepareSheetState extends State<RecipePrepareSheet> {
  final _kgCtrl = TextEditingController(text: '1');

  bool _busy = false; // يمنع الضغط المزدوج
  bool _done = false; // حالة نجاح التحضير
  String? _doneMsg; // رسالة النجاح

  // ✅ تحميل التوليفة مرة واحدة فقط
  late Future<void> _recipeFuture;
  String _name = '';
  String _variant = '';
  List<RecipeComponent> _comps = const [];

  @override
  void initState() {
    super.initState();
    _recipeFuture = _loadRecipeOnce();
  }

  Future<void> _loadRecipeOnce() async {
    final snap = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();

    if (!snap.exists) {
      throw 'لم يتم العثور على التوليفة';
    }
    final m = snap.data() ?? {};
    _name = (m['name'] ?? '').toString();
    _variant = (m['variant'] ?? '').toString();
    _comps = ((m['components'] ?? []) as List)
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .map(RecipeComponent.fromMap)
        .toList();

    if (_comps.isEmpty) {
      throw 'لا توجد مكونات في هذه التوليفة';
    }
  }

  double _parseKg() {
    final raw = _kgCtrl.text.trim().replaceAll(',', '.');
    final d = double.tryParse(raw);
    return (d == null || d <= 0) ? 1.0 : d;
  }

  double _numOf(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toDouble();
    }
    for (final k in keys) {
      final v = m[k];
      if (v is String) {
        final d = double.tryParse(v.replaceAll(',', '.').trim());
        if (d != null) return d;
      }
    }
    return 0.0;
  }

  Future<void> _prepare() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _done = false;
      _doneMsg = null;
    });

    try {
      final totalKg = _parseKg();
      final totalGrams = (totalKg * 1000).round();

      // ابحث/أنشئ دوك المنتج النهائي في blends بالاسم + النسخة
      final blendsQuery = await FirebaseFirestore.instance
          .collection('blends')
          .where('name', isEqualTo: _name)
          .where('variant', isEqualTo: _variant)
          .limit(1)
          .get();

      final destBlendRef = blendsQuery.docs.isNotEmpty
          ? blendsQuery.docs.first.reference
          : FirebaseFirestore.instance.collection('blends').doc();

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final updates = <DocumentReference<Map<String, dynamic>>, int>{};

        // فحص المخزون أولًا
        for (final c in _comps) {
          final grams = ((c.percent / 100.0) * totalGrams).round();
          final ref = FirebaseFirestore.instance
              .collection(c.coll)
              .doc(c.itemId);
          final snap = await tx.get(ref);
          if (!snap.exists) throw 'مكوّن غير موجود: ${c.name}';
          final m = snap.data() ?? {};
          final currentStock = _numOf(m, [
            'stock',
            'stockGrams',
            'grams',
            'qty',
          ]);
          if (currentStock - grams < -0.0001) {
            throw 'مخزون غير كافٍ في "${c.name}${c.variant.isEmpty ? '' : ' — ${c.variant}'}": '
                'متاح ${currentStock.toStringAsFixed(0)} جم';
          }
          updates[ref] = grams;
        }

        // خصم المكونات
        for (final entry in updates.entries) {
          final ref = entry.key;
          final grams = entry.value;
          final snap = await tx.get(ref);
          final m = snap.data() ?? {};
          final currentStock = _numOf(m, [
            'stock',
            'stockGrams',
            'grams',
            'qty',
          ]);
          tx.update(ref, {'stock': currentStock - grams});
        }

        // زيادة مخزون المنتج النهائي
        final destSnap = await tx.get(destBlendRef);
        final destData =
            destSnap.data() ?? {'name': _name, 'variant': _variant, 'stock': 0};
        final destStock = _numOf(destData, [
          'stock',
          'stockGrams',
          'grams',
          'qty',
        ]);
        tx.set(destBlendRef, {
          'name': _name,
          'variant': _variant,
          'stock': destStock + totalGrams,
        }, SetOptions(merge: true));

        // تسجيل العملية
        final prepRef = FirebaseFirestore.instance
            .collection('recipe_preps')
            .doc();
        tx.set(prepRef, {
          'recipe_id': widget.recipeId,
          'name': _name,
          'variant': _variant,
          'amount_kg': totalKg,
          'amount_grams': totalGrams,
          'created_at': FieldValue.serverTimestamp(),
          'components': _comps
              .map(
                (c) => {
                  'coll': c.coll,
                  'item_id': c.itemId,
                  'name': c.name,
                  'variant': c.variant,
                  'percent': c.percent,
                },
              )
              .toList(),
        });
      });

      if (!mounted) return;
      _doneMsg = 'تم تحضير $_name — ${totalKg.toStringAsFixed(2)} كجم';
      _done = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_doneMsg!)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التحضير: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        // ✅ Future واحد ثابت – مش بيتغيّر مع كل كتابة
        child: FutureBuilder<void>(
          future: _recipeFuture,
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (s.hasError) {
              return SizedBox(
                height: 160,
                child: Center(child: Text('تعذر التحميل: ${s.error}')),
              );
            }

            final kg = _parseKg();
            final gramsTotal = (kg * 1000).round();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تحضير: $_name',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),

                if (_done && _doneMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_doneMsg!)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

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
                        onChanged: (_) =>
                            setState(() {}), // مجرد إعادة حساب الجرامات محليًا
                        enabled: !_busy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.brown.shade200),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.brown.shade50,
                      ),
                      child: Text('جم: ${gramsTotal.toStringAsFixed(0)}'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.brown.shade50.withOpacity(.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المكونات:'),
                      const SizedBox(height: 6),
                      ..._comps.map((c) {
                        final grams = ((kg * 1000) * (c.percent / 100)).round();
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(
                              child: Text(
                                '${c.name}${c.variant.isEmpty ? '' : ' — ${c.variant}'}  '
                                '(${c.percent.toStringAsFixed(1)}%)  ≈ $grams جم',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _prepare,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.scale_outlined),
                        label: Text(
                          _done ? 'تحضير دفعة أخرى' : 'تحضير التوليفة',
                        ),
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
}
