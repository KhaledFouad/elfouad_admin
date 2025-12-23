import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

class EditItemSheet extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  const EditItemSheet({super.key, required this.doc});

  @override
  State<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<EditItemSheet> {
  // مشتركات
  final _name = TextEditingController();
  final _variant = TextEditingController();
  final _stock = TextEditingController();

  // بن/توليفات
  final _sellPerKg = TextEditingController();
  final _costPerKg = TextEditingController();
  final _minLevel = TextEditingController();

  // مشروبات
  final _sellCup = TextEditingController();
  final _costCup = TextEditingController();
  final _doubleCostCup = TextEditingController();

  bool _busy = false;
  late bool _isBeans; // singles || blends
  late bool _isDrink; // drinks

  @override
  void initState() {
    super.initState();
    final m = widget.doc.data() ?? {};
    final parentId = widget.doc.reference.parent.id;

    // 1) نحاول بالمسار
    _isBeans = parentId == 'singles' || parentId == 'blends';
    _isDrink = parentId == 'drinks';

    // 2) fallback بالحقول (أضمن)
    if (!_isBeans && !_isDrink) {
      final unit = (m['unit'] ?? '').toString().toLowerCase();
      _isBeans =
          m.containsKey('sellPricePerKg') ||
          m.containsKey('costPricePerKg') ||
          unit == 'g';
      _isDrink = !_isBeans;
    }

    // تعبئة الحقول المشتركة
    _name.text = (m['name'] ?? '').toString();
    _variant.text = (m['variant'] ?? '').toString();
    _stock.text = _n(m['stock']).toStringAsFixed(0);

    // تعبئة حسب النوع
    if (_isBeans) {
      _sellPerKg.text = _n(m['sellPricePerKg']).toStringAsFixed(2);
      _costPerKg.text = _n(m['costPricePerKg']).toStringAsFixed(2);
      _minLevel.text = _n(m['minLevel']).toStringAsFixed(0);
    } else {
      _sellCup.text = _n(m['sellPrice']).toStringAsFixed(2);
      _costCup.text = _n(m['costPrice']).toStringAsFixed(2);
      _doubleCostCup.text = _n(m['doubleCostPrice']).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _stock.dispose();
    _sellPerKg.dispose();
    _costPerKg.dispose();
    _minLevel.dispose();
    _sellCup.dispose();
    _costCup.dispose();
    _doubleCostCup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '${_name.text}${_variant.text.isEmpty ? '' : ' — ${_variant.text}'}';
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
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            _tf(_name, AppStrings.nameLabel, TextInputType.text),
            const SizedBox(height: 8),
            _tf(_variant, AppStrings.roastOptionalLabel, TextInputType.text),
            const SizedBox(height: 8),
            _tf(
              _stock,
              AppStrings.stockGramsLabel,
              const TextInputType.numberWithOptions(decimal: false),
            ),

            if (_isBeans) ...[
              const SizedBox(height: 8),
              _tf(
                _sellPerKg,
                AppStrings.pricePerKgLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              _tf(
                _costPerKg,
                AppStrings.costPerKgLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ), // ✅ ظاهر دائمًا
              const SizedBox(height: 8),
              _tf(
                _minLevel,
                AppStrings.minWarningLevelLabel,
                const TextInputType.numberWithOptions(decimal: false),
              ),
            ] else ...[
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              _tf(
                _doubleCostCup,
                AppStrings.doubleCostOptionalLabel,
                const TextInputType.numberWithOptions(decimal: true),
              ), // ✅
            ],

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
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        labelText: '',
      ).copyWith(labelText: label),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'variant': _variant.text.trim(),
        'stock': _n(_stock.text),
      };

      if (_isBeans) {
        data['sellPricePerKg'] = _n(_sellPerKg.text);
        data['costPricePerKg'] = _n(_costPerKg.text); // ✅
        data['minLevel'] = _n(_minLevel.text);
      } else {
        data['sellPrice'] = _n(_sellCup.text);
        data['costPrice'] = _n(_costCup.text); // ✅
        final dc = _n(_doubleCostCup.text);
        if (dc > 0) {
          data['doubleCostPrice'] = dc; // ✅ يحفظ الدوبل
        } else {
          // امسح الحقل لو صفر/فاضي عشان ما يبقاش مضلل
          data['doubleCostPrice'] = FieldValue.delete();
        }
      }

      await widget.doc.reference.update(data);
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

  double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }
}
