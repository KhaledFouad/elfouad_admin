import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

class PrepareBatchSheet extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> recipeSnap;
  const PrepareBatchSheet({super.key, required this.recipeSnap});

  @override
  State<PrepareBatchSheet> createState() => _PrepareBatchSheetState();
}

class _PrepareBatchSheetState extends State<PrepareBatchSheet> {
  final _kgCtrl = TextEditingController(text: '1');
  bool _busy = false;

  @override
  void dispose() {
    _kgCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final kg = double.tryParse(_kgCtrl.text.replaceAll(',', '.')) ?? 0;
    if (kg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.enterKgPrompt)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final recipeRef = widget.recipeSnap.reference;
      // نحدّد ID لِسجلّ الإنتاج (لو حابب تسجل لوج)
      final prodRef = db.collection('productions').doc();

      await db.runTransaction((tx) async {
        // اقرأ آخر نسخة من التوليفة داخل الترانزاكشن
        final snap = await tx.get(recipeRef);
        if (!snap.exists) throw AppStrings.recipeNotFound;
        final m = snap.data() ?? <String, dynamic>{};
        final name = (m['name'] ?? '').toString();
        final comps = (m['components'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

        final totalGrams = kg * 1000.0;
        final producedLines = <Map<String, dynamic>>[];

        for (final c in comps) {
          final coll = (c['coll'] ?? '').toString(); // singles | blends
          final id = (c['itemId'] ?? c['id'] ?? '').toString();
          final p = ((c['percent'] ?? 0) as num).toDouble();
          if (coll.isEmpty || id.isEmpty || p <= 0) continue;

          final grams = totalGrams * (p / 100.0);
          final itemRef = db.collection(coll).doc(id);

          // خصم من المخزون
          tx.update(itemRef, {'stock': FieldValue.increment(-grams)});

          producedLines.add({
            'coll': coll,
            'item_id': id,
            'name': (c['name'] ?? '').toString(),
            'variant': (c['variant'] ?? '').toString(),
            'percent': p,
            'grams_used': grams,
          });
        }

        // (اختياري) سجّل عملية التحضير
        tx.set(prodRef, {
          'recipe_id': recipeRef.id,
          'recipe_name': name,
          'kg_prepared': kg,
          'grams_total': totalGrams,
          'lines': producedLines,
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.prepareSuccess(kg))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.prepareFailed(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.recipeSnap.data()?['name'] ?? '').toString();
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
            AppStrings.prepareAmountTitle(name),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kgCtrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.kgLabel,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text(AppStrings.actionCancel),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text(AppStrings.prepareAndDeductLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
