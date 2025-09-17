import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import 'providers.dart';

class ProductEditSheet extends ConsumerStatefulWidget {
  final Product? initial;
  const ProductEditSheet({super.key, this.initial});

  @override
  ConsumerState<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends ConsumerState<ProductEditSheet> {
  final _form = GlobalKey<FormState>();
  late String _type;
  late TextEditingController _name;
  late TextEditingController _roast;
  late TextEditingController _family;
  late TextEditingController _pricePerKg;
  late TextEditingController _costPerKg;
  late TextEditingController _pricePerCup;
  late TextEditingController _costPerCup;
  late TextEditingController _stockGrams;
  late TextEditingController _stockCups;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _type = p?.type ?? 'single';
    _name = TextEditingController(text: p?.name ?? '');
    _roast = TextEditingController(text: p?.roast ?? '');
    _family = TextEditingController(text: p?.family ?? '');
    _pricePerKg = TextEditingController(text: p?.pricePerKg?.toString() ?? '');
    _costPerKg = TextEditingController(text: p?.costPerKg?.toString() ?? '');
    _pricePerCup = TextEditingController(
      text: p?.pricePerCup?.toString() ?? '',
    );
    _costPerCup = TextEditingController(text: p?.costPerCup?.toString() ?? '');
    _stockGrams = TextEditingController(text: (p?.stockGrams ?? 0).toString());
    _stockCups = TextEditingController(text: (p?.stockCups ?? '').toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _roast.dispose();
    _family.dispose();
    _pricePerKg.dispose();
    _costPerKg.dispose();
    _pricePerCup.dispose();
    _costPerCup.dispose();
    _stockGrams.dispose();
    _stockCups.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      double? d(TextEditingController c) {
        final t = c.text.trim();
        if (t.isEmpty) return null;
        return double.tryParse(t.replaceAll(',', '.'));
      }

      double dReq(TextEditingController c) {
        final t = c.text.trim();
        return double.tryParse(t.replaceAll(',', '.')) ?? 0.0;
      }

      final repo = ref.read(productsRepoProvider);
      final pOld = widget.initial;
      final p = Product(
        id: pOld?.id ?? '',
        type: _type,
        name: _name.text.trim(),
        roast: _roast.text.trim().isEmpty ? null : _roast.text.trim(),
        family: _family.text.trim().isEmpty ? null : _family.text.trim(),
        pricePerKg: _type != 'drink' ? d(_pricePerKg) : null,
        costPerKg: _type != 'drink' ? d(_costPerKg) : null,
        pricePerCup: _type == 'drink' ? d(_pricePerCup) : null,
        costPerCup: _type == 'drink' ? d(_costPerCup) : null,
        stockGrams: dReq(_stockGrams),
        stockCups: _type == 'drink' ? d(_stockCups) : null,
      );
      await repo.upsert(p, oldType: pOld?.type);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _form,
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
              widget.initial == null ? 'إضافة منتج' : 'تعديل المنتج',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('منفرد'),
                  selected: _type == 'single',
                  onSelected: (_) => setState(() => _type = 'single'),
                ),
                ChoiceChip(
                  label: const Text('توليفة جاهزة'),
                  selected: _type == 'ready_blend',
                  onSelected: (_) => setState(() => _type = 'ready_blend'),
                ),
                ChoiceChip(
                  label: const Text('مشروب'),
                  selected: _type == 'drink',
                  onSelected: (_) => setState(() => _type = 'drink'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 8),
            if (_type != 'drink') ...[
              TextFormField(
                controller: _roast,
                decoration: const InputDecoration(
                  labelText: 'درجة التحميص',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _family,
                decoration: const InputDecoration(
                  labelText: 'العائلة/المنشأ (اختياري)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pricePerKg,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر/كجم',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _costPerKg,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'تكلفة/كجم',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pricePerCup,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر/كوب',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _costPerCup,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'تكلفة/كوب',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockGrams,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المخزون (جرام)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (_type == 'drink') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _stockCups,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المخزون (أكواب)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
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
                    onPressed: _busy ? null : _save,
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
      ),
    );
  }
}
