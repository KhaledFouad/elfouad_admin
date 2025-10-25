import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/recipes/recipes_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elfouad_admin/presentation/inventory/providers.dart';

class RecipeEditSheet extends ConsumerStatefulWidget {
  final String? recipeId; // null => جديد
  const RecipeEditSheet({super.key, this.recipeId});

  @override
  ConsumerState<RecipeEditSheet> createState() => _RecipeEditSheetState();
}

class _RecipeEditSheetState extends ConsumerState<RecipeEditSheet> {
  final _name = TextEditingController();
  final _variant = TextEditingController(); // جديد
  bool _busy = false;

  List<RecipeComponent> _comps = [];

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();
    final m = doc.data();
    if (m != null) {
      _name.text = (m['name'] ?? '').toString();
      _variant.text = (m['variant'] ?? '').toString(); // جديد
      _comps = ((m['components'] ?? []) as List)
          .map(
            (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
          )
          .map(RecipeComponent.fromMap)
          .toList();
      if (mounted) setState(() {});
    }
  }

  int get _sumPercentInt => _comps.fold<int>(
    0,
    (s, c) => s + (c.percent.isNaN ? 0 : c.percent.round()),
  );
  int get _remainingInt => (100 - _sumPercentInt);

  bool get _validToSave =>
      _name.text.trim().isNotEmpty &&
      _variant.text.trim().isNotEmpty && // لازم للتحضير
      _comps.isNotEmpty &&
      _sumPercentInt == 100;

  Future<void> _save() async {
    if (_busy) return;
    if (!_validToSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل البيانات: الاسم + التحميص + 100%')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final now = FieldValue.serverTimestamp();
      final payload = {
        'name': _name.text.trim(),
        'variant': _variant.text.trim(), // جديد
        'components': _comps.map((c) => c.toMap()).toList(),
        'updated_at': now,
        if (widget.recipeId == null) 'created_at': now,
      };

      final col = FirebaseFirestore.instance.collection('recipes');
      if (widget.recipeId == null) {
        await col.add(payload);
      } else {
        await col.doc(widget.recipeId).update(payload);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التوليفة')));
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickItem({
    required String coll, // 'singles' | 'blends'
    required AsyncValue<List<InventoryRow>> source,
  }) async {
    final chosen = await showDialog<InventoryRow>(
      context: context,
      builder: (_) {
        final search = TextEditingController();
        return AlertDialog(
          title: Text(coll == 'singles' ? 'اختر صنف منفرد' : 'اختر توليفة'),
          content: SizedBox(
            width: 460,
            height: 520,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: 'بحث بالاسم/الفاريانت',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => (context as Element).markNeedsBuild(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: source.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('تعذر التحميل: $e')),
                    data: (rows) {
                      final q = search.text.trim().toLowerCase();
                      final filtered = q.isEmpty
                          ? rows
                          : rows.where((r) {
                              final t = '${r.name} ${r.variant}'.toLowerCase();
                              return t.contains(q);
                            }).toList();
                      if (filtered.isEmpty) {
                        return const Center(child: Text('لا نتائج'));
                      }
                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          return ListTile(
                            title: Text(
                              r.variant.isEmpty
                                  ? r.name
                                  : '${r.name} — ${r.variant}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Wrap(
                              spacing: 8,
                              children: [
                                Text('مخزون: ${r.stockG.toStringAsFixed(0)}جم'),
                                Text(
                                  'سعر/كجم: ${r.sellPerKg.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                            onTap: () => Navigator.pop(context, r),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );

    if (chosen != null) {
      setState(() {
        _comps.add(
          RecipeComponent(
            coll: coll,
            itemId: chosen.id,
            name: chosen.name,
            variant: chosen.variant,
            percent: 0.0,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final singles = ref.watch(singlesStreamProvider);
    final blends = ref.watch(blendsStreamProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
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
            widget.recipeId == null ? 'توليفة جديدة' : 'تعديل توليفة',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 12),

          // الاسم + التحميص
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'اسم التوليفة',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _variant,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'التحميص',
                    hintText: 'مثال: وسط',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة صنف منفرد'),
                  onPressed: () => _pickItem(coll: 'singles', source: singles),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة توليفة جاهزة'),
                  onPressed: () => _pickItem(coll: 'blends', source: blends),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.brown.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.percent),
                const SizedBox(width: 8),
                Text(
                  'المجموع: ${_sumPercentInt}%   •   المتبقي: ${_remainingInt}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: (_sumPercentInt == 100) ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          if (_comps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'أضف مكونات للتوليفة',
                style: TextStyle(color: Colors.brown.shade300),
              ),
            ),

          Column(
            children: _comps.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final percentCtrl = TextEditingController(
                text: c.percent.toStringAsFixed(1),
              );

              void updatePercent(double v) {
                setState(() {
                  _comps[i] = RecipeComponent(
                    coll: c.coll,
                    itemId: c.itemId,
                    name: c.name,
                    variant: c.variant,
                    percent: v.clamp(0, 100),
                  );
                });
              }

              final title = c.variant.isEmpty
                  ? c.name
                  : '${c.name} — ${c.variant}';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.brown.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            c.coll == 'singles'
                                ? Icons.coffee_outlined
                                : Icons.auto_awesome_mosaic,
                            size: 18,
                            color: Colors.brown,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'حذف',
                            onPressed: () => setState(() => _comps.removeAt(i)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: c.percent.clamp(0, 100),
                              min: 0,
                              max: 100,
                              divisions: 100,
                              label: '${c.percent.toStringAsFixed(1)}%',
                              onChanged: (v) => updatePercent(v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 86,
                            child: TextField(
                              controller: percentCtrl,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (v) {
                                final x =
                                    double.tryParse(v.replaceAll(',', '.')) ??
                                    c.percent;
                                updatePercent(x);
                              },
                              decoration: const InputDecoration(
                                suffixText: '%',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                  onPressed: _busy || !_validToSave ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
