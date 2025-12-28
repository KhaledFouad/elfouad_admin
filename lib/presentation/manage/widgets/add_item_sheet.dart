import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

enum NewItemType { single, blend, drink, extra }

class AddItemSheet extends StatefulWidget {
  final NewItemType initialType;

  const AddItemSheet({super.key, this.initialType = NewItemType.blend});
  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  late NewItemType _t;
  final _name = TextEditingController();
  final _variant = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _category = TextEditingController();
  final _extraUnit = TextEditingController(text: 'piece');
  // وزن/سعر/تكلفة
  final _sellPerKg = TextEditingController(text: '0.0'); // single/blend
  final _costPerKg = TextEditingController(text: '0.0'); // ✅

  // drinks
  final _sellCup = TextEditingController(text: '0.0');
  final _costCup = TextEditingController(text: '0.0'); // ✅
  final _extraPrice = TextEditingController(text: '0.0');
  final _extraCost = TextEditingController(text: '0.0');
  bool _extraActive = true;

  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _t = widget.initialType;
  }

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _stock.dispose();
    _sellPerKg.dispose();
    _costPerKg.dispose();
    _sellCup.dispose();
    _costCup.dispose();
    _category.dispose();
    _extraUnit.dispose();
    _extraPrice.dispose();
    _extraCost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
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
            const Text(
              AppStrings.addNewItemTitle,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 10),

            // تبويب الأنواع
            SegmentedButton<NewItemType>(
              segments: const [
                ButtonSegment(
                  value: NewItemType.single,
                  label: Text(AppStrings.singleSegmentLabel),
                ),
                ButtonSegment(
                  value: NewItemType.blend,
                  label: Text(AppStrings.blendLabel),
                ),
                ButtonSegment(
                  value: NewItemType.drink,
                  label: Text(AppStrings.drinkLabel),
                ),
                ButtonSegment(
                  value: NewItemType.extra,
                  label: Text(AppStrings.snacksLabel),
                ),
              ],
              selected: {_t},
              onSelectionChanged: (s) => setState(() => _t = s.first),
            ),
            const SizedBox(height: 10),

            // 🟤 كيبورد نصي لاسم/تحميص
            _tf(_name, AppStrings.nameLabel, TextInputType.text),
            const SizedBox(height: 8),
            if (_t == NewItemType.extra) ...[
              _tf(
                _category,
                AppStrings.categoryOptionalLabel,
                TextInputType.text,
              ),
              const SizedBox(height: 8),
              _tf(_extraUnit, AppStrings.unitExampleLabel, TextInputType.text),
            ] else ...[
              _tf(_variant, AppStrings.roastOptionalLabel, TextInputType.text),
              const SizedBox(height: 8),
            ],
            if (_t == NewItemType.extra) ...[
              _tf(
                _stock,
                AppStrings.stockUnitsLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              _tf(
                _extraPrice,
                AppStrings.sellPricePerUnitLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              _tf(
                _extraCost,
                AppStrings.costPerUnitShortLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SwitchListTile.adaptive(
                  value: _extraActive,
                  onChanged: (v) => setState(() => _extraActive = v),
                  title: const Text(AppStrings.activeQuestionLabel),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const SizedBox(height: 12),
            ] else if (_t != NewItemType.drink) ...[
              _tf(
                _stock,
                AppStrings.stockGramsLabel,
                const TextInputType.numberWithOptions(decimal: false),
              ),
              const SizedBox(height: 8),
              _tf(
                _sellPerKg,
                AppStrings.pricePerKgLabelDefinite,
                const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              _tf(
                _costPerKg,
                AppStrings.costPerKgLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ), // ✅
            ] else ...[
              _tf(
                _sellCup,
                AppStrings.cupPriceLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              _tf(
                _costCup,
                AppStrings.cupCostLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ), // ✅
            ],
            if (_t != NewItemType.extra) const SizedBox(height: 12),
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
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text(AppStrings.actionSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, TextInputType kt) {
    return TextFormField(
      controller: c,
      textAlign: TextAlign.center,
      keyboardType: kt,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now().toUtc();

      if (_t == NewItemType.drink) {
        await db.collection('drinks').add({
          'name': _name.text.trim(),
          'unit': 'cup',
          'sellPrice': _num(_sellCup.text),
          'costPrice': _num(_costCup.text), // ✅
          'image': 'assets/drinks.jpg',
          'roastLevels': <String>[],
          'createdAt': now,
        });
      } else if (_t == NewItemType.extra) {
        await db.collection('extras').add({
          'name': _name.text.trim(),
          'category': _category.text.trim(),
          'unit': _extraUnit.text.trim().isEmpty
              ? 'piece'
              : _extraUnit.text.trim(),
          'stock_units': _num(_stock.text),
          'price_sell': _num(_extraPrice.text),
          'cost_unit': _num(_extraCost.text),
          'active': _extraActive,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        final col = _t == NewItemType.single ? 'singles' : 'blends';
        await db.collection(col).add({
          'name': _name.text.trim(),
          'variant': _variant.text.trim(),
          'unit': 'g',
          'stock': _num(_stock.text),
          'minLevel': 0,
          'sellPricePerKg': _num(_sellPerKg.text),
          'costPricePerKg': _num(_costPerKg.text), // ✅
          'image': col == 'singles'
              ? 'assets/singles.jpg'
              : 'assets/blends.jpg',
          'createdAt': now,
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }
}
