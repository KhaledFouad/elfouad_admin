import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

class ExtraEditSheet extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> snap;
  const ExtraEditSheet({super.key, required this.snap});

  @override
  State<ExtraEditSheet> createState() => _ExtraEditSheetState();
}

class _ExtraEditSheetState extends State<ExtraEditSheet> {
  late Map<String, dynamic> _data;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _unit = TextEditingController();
  final _priceSell = TextEditingController();
  final _costUnit = TextEditingController();
  final _stockUnits = TextEditingController();
  bool _active = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _data = widget.snap.data() ?? <String, dynamic>{};
    _name.text = (_data['name'] ?? '').toString();
    _category.text = (_data['category'] ?? '').toString();
    _unit.text = (_data['unit'] ?? '').toString();
    final stock = _num(_data['stock_units'] ?? _data['stockUnits']);
    if (stock > 0) _stockUnits.text = _format(stock);
    _priceSell.text = _format(_num(_data['price_sell'] ?? _data['priceSell']));
    _costUnit.text = _format(_num(_data['cost_unit'] ?? _data['costUnit']));
    _active = (_data['active'] ?? true) == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _unit.dispose();
    _priceSell.dispose();
    _costUnit.dispose();
    _stockUnits.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  String _format(double v) {
    if (v == v.roundToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now().toUtc();
      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }
      final name = _name.text.trim();
      final category = _category.text.trim();
      final sell = _num(_priceSell.text);
      final cost = _num(_costUnit.text);
      final upd = <String, dynamic>{
        'name': name,
        'category': category,
        'unit': _unit.text.trim().isEmpty ? 'piece' : _unit.text.trim(),
        'price_sell': sell,
        'cost_unit': cost,
        'stock_units': _num(_stockUnits.text),
        'active': _active,
        'updated_at': now,
      };

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
      ).showSnackBar(SnackBar(content: Text(AppStrings.saveFailedAccented(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              AppStrings.editExtraTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _field(
              AppStrings.nameLabel,
              _name,
              validator: (v) => _requiredText(v, AppStrings.nameRequiredPrompt),
            ),
            const SizedBox(height: 8),
            _field(
              AppStrings.categoryLabel,
              _category,
              validator: (v) =>
                  _requiredText(v, AppStrings.categoryRequiredPrompt),
            ),
            const SizedBox(height: 8),
            _field(AppStrings.unitLabel, _unit),
            const SizedBox(height: 8),
            _field(AppStrings.stockUnitsLabel, _stockUnits, numKeyboard: true),
            const SizedBox(height: 8),
            _field(
              AppStrings.sellPricePerUnitLabel,
              _priceSell,
              numKeyboard: true,
              validator: (v) =>
                  _requiredPositive(v, AppStrings.sellPriceRequiredPrompt),
            ),
            const SizedBox(height: 8),
            _field(
              AppStrings.costPerUnitShortLabel,
              _costUnit,
              numKeyboard: true,
              validator: (v) =>
                  _requiredPositive(v, AppStrings.costPriceRequiredPrompt),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text(AppStrings.activeQuestionLabel),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
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
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool numKeyboard = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: numKeyboard
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      autovalidateMode: validator == null
          ? AutovalidateMode.disabled
          : AutovalidateMode.onUserInteraction,
      validator: validator,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ).copyWith(labelText: label),
    );
  }

  String? _requiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _requiredPositive(String? value, String message) {
    if (_num(value) <= 0) return message;
    return null;
  }
}
