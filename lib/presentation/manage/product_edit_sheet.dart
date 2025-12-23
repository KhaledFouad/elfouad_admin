import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

class ProductEditSheet extends StatefulWidget {
  final String collection; // 'drinks' | 'singles' | 'blends'
  final DocumentSnapshot<Map<String, dynamic>> snap;
  const ProductEditSheet({
    super.key,
    required this.collection,
    required this.snap,
  });

  @override
  State<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<ProductEditSheet> {
  late Map<String, dynamic> m;
  final _name = TextEditingController();
  final _variant = TextEditingController();
  final _unit = TextEditingController();

  // عام
  final _stock = TextEditingController(); // جرام للأصناف/التوليفات

  // singles/blends
  final _sellPerKg = TextEditingController();
  final _costPerKg = TextEditingController();
  final _spicesPrice = TextEditingController(); // إيراد التحويج/كجم
  final _spicesCost = TextEditingController(); // تكلفة التحويج/كجم

  // drinks
  final _sellPrice = TextEditingController();
  final _costPrice = TextEditingController();
  final _doublePrice = TextEditingController();
  final _doubleCost = TextEditingController();
  final _spicedCupCost = TextEditingController();
  final _spicedDoubleCupCost = TextEditingController();
  final _usedAmount = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    m = widget.snap.data() ?? {};
    _name.text = (m['name'] ?? '').toString();
    _variant.text = (m['variant'] ?? '').toString();
    _unit.text = (m['unit'] ?? '').toString();

    // مخزون (مش شرط موجود في drinks)
    final stock = _n(m['stock']);
    if (stock > 0) _stock.text = stock.toStringAsFixed(0);

    if (widget.collection != 'drinks') {
      _sellPerKg.text = _n(m['sellPricePerKg']).toStringAsFixed(2);
      _costPerKg.text = _n(m['costPricePerKg']).toStringAsFixed(2);
      _spicesPrice.text = _n(m['spicesPrice']).toStringAsFixed(2);
      _spicesCost.text = _n(m['spicesCost']).toStringAsFixed(2);
    } else {
      _sellPrice.text = _n(m['sellPrice']).toStringAsFixed(2);
      _costPrice.text = _n(m['costPrice']).toStringAsFixed(2);
      _doublePrice.text = _n(m['doublePrice']).toStringAsFixed(2);
      _doubleCost.text = _n(m['doubleCost']).toStringAsFixed(2);
      _spicedCupCost.text = _n(m['spicedCupCost']).toStringAsFixed(2);
      _spicedDoubleCupCost.text = _n(
        m['spicedDoubleCupCost'],
      ).toStringAsFixed(2);
      final ua = _n(m['usedAmount']);
      if (ua > 0) _usedAmount.text = ua.toStringAsFixed(0);
    }
  }

  double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _unit.dispose();
    _stock.dispose();
    _sellPerKg.dispose();
    _costPerKg.dispose();
    _spicesPrice.dispose();
    _spicesCost.dispose();
    _sellPrice.dispose();
    _costPrice.dispose();
    _doublePrice.dispose();
    _doubleCost.dispose();
    _spicedCupCost.dispose();
    _spicedDoubleCupCost.dispose();
    _usedAmount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final upd = <String, dynamic>{
        'name': _name.text.trim(),
        if (widget.collection != 'drinks') 'variant': _variant.text.trim(),
        if (_unit.text.trim().isNotEmpty) 'unit': _unit.text.trim(),
      };

      // مخزون: نحفظه لو اتكتب
      final stockTxt = _stock.text.trim();
      if (stockTxt.isNotEmpty) {
        upd['stock'] =
            double.tryParse(stockTxt.replaceAll(',', '.')) ?? _n(m['stock']);
      }

      if (widget.collection != 'drinks') {
        upd['sellPricePerKg'] =
            double.tryParse(_sellPerKg.text.replaceAll(',', '.')) ??
            _n(m['sellPricePerKg']);
        upd['costPricePerKg'] =
            double.tryParse(_costPerKg.text.replaceAll(',', '.')) ??
            _n(m['costPricePerKg']);
        upd['spicesPrice'] =
            double.tryParse(_spicesPrice.text.replaceAll(',', '.')) ??
            _n(m['spicesPrice']);
        upd['spicesCost'] =
            double.tryParse(_spicesCost.text.replaceAll(',', '.')) ??
            _n(m['spicesCost']);
      } else {
        upd['sellPrice'] =
            double.tryParse(_sellPrice.text.replaceAll(',', '.')) ??
            _n(m['sellPrice']);
        upd['costPrice'] =
            double.tryParse(_costPrice.text.replaceAll(',', '.')) ??
            _n(m['costPrice']);
        upd['doublePrice'] =
            double.tryParse(_doublePrice.text.replaceAll(',', '.')) ??
            _n(m['doublePrice']);
        upd['doubleCost'] =
            double.tryParse(_doubleCost.text.replaceAll(',', '.')) ??
            _n(m['doubleCost']);
        upd['spicedCupCost'] =
            double.tryParse(_spicedCupCost.text.replaceAll(',', '.')) ??
            _n(m['spicedCupCost']);
        upd['spicedDoubleCupCost'] =
            double.tryParse(_spicedDoubleCupCost.text.replaceAll(',', '.')) ??
            _n(m['spicedDoubleCupCost']);
        final usedTxt = _usedAmount.text.trim();
        if (usedTxt.isNotEmpty) {
          upd['usedAmount'] =
              double.tryParse(usedTxt.replaceAll(',', '.')) ??
              _n(m['usedAmount']);
        }
      }

      await widget.snap.reference.update(upd);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.saveSuccess)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(AppStrings.saveFailedAccented(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDrinks = widget.collection == 'drinks';
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
            isDrinks ? AppStrings.editDrinkTitle : AppStrings.editItemTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 12),

          _t(AppStrings.nameLabel, _name),
          if (!isDrinks) ...[
            const SizedBox(height: 8),
            _t(AppStrings.roastVariantLabel, _variant),
          ],
          const SizedBox(height: 8),
          _t(AppStrings.unitOptionalLabel, _unit),

          const SizedBox(height: 12),
          _t(
            isDrinks
                ? AppStrings.stockOptionalLabel
                : AppStrings.stockGramsShortLabel,
            _stock,
            numKeyboard: true,
          ),

          const SizedBox(height: 12),
          if (!isDrinks) ...[
            _t(AppStrings.pricePerKgLabel, _sellPerKg, numKeyboard: true),
            const SizedBox(height: 8),
            _t(AppStrings.costPerKgLabel, _costPerKg, numKeyboard: true),
            const SizedBox(height: 8),
            _t(
              AppStrings.spicePricePerKgLabel,
              _spicesPrice,
              numKeyboard: true,
            ),
            const SizedBox(height: 8),
            _t(
              AppStrings.spiceCostPerKgLabel,
              _spicesCost,
              numKeyboard: true,
            ),
          ] else ...[
            _t(AppStrings.cupPriceLabel, _sellPrice, numKeyboard: true),
            const SizedBox(height: 8),
            _t(AppStrings.cupCostLabel, _costPrice, numKeyboard: true),
            const SizedBox(height: 8),
            _t(AppStrings.doublePriceLabel, _doublePrice, numKeyboard: true),
            const SizedBox(height: 8),
            _t(AppStrings.doubleCostLabel, _doubleCost, numKeyboard: true),
            const SizedBox(height: 8),
            _t(
              AppStrings.spicedCupCostLabel,
              _spicedCupCost,
              numKeyboard: true,
            ),
            const SizedBox(height: 8),
            _t(
              AppStrings.spicedDoubleCostLabel,
              _spicedDoubleCupCost,
              numKeyboard: true,
            ),
            const SizedBox(height: 8),
            _t(AppStrings.usedAmountLabel, _usedAmount, numKeyboard: true),
          ],

          const SizedBox(height: 14),
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
    );
  }

  Widget _t(String label, TextEditingController c, {bool numKeyboard = false}) {
    return TextField(
      controller: c,
      textAlign: TextAlign.center,
      keyboardType: numKeyboard
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ).copyWith(labelText: label),
    );
  }
}
