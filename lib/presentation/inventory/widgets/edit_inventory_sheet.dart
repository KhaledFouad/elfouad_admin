import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/providers.dart';

class EditInventorySheet extends StatefulWidget {
  final InventoryRow row;
  const EditInventorySheet({super.key, required this.row});

  @override
  State<EditInventorySheet> createState() => _EditInventorySheetState();
}

class _EditInventorySheetState extends State<EditInventorySheet> {
  final _name = TextEditingController();
  final _variant = TextEditingController();
  final _stock = TextEditingController();
  final _sellPerKg = TextEditingController();
  final _costPerKg = TextEditingController();
  final _minLevel = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _name.text = r.name;
    _variant.text = r.variant;
    _stock.text = r.stockG.toStringAsFixed(0);
    _sellPerKg.text = r.sellPerKg.toStringAsFixed(2);
    _costPerKg.text = r.costPerKg.toStringAsFixed(2); // قابل للتعديل
    _minLevel.text = r.minLevelG.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _stock.dispose();
    _sellPerKg.dispose();
    _costPerKg.dispose();
    _minLevel.dispose();
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
            ), // ✅
            const SizedBox(height: 8),
            _tf(
              _minLevel,
              AppStrings.minWarningLevelLabel,
              const TextInputType.numberWithOptions(decimal: false),
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
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        labelText: label,
      ),
    );
  }

  double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString().replaceAll(',', '.')) ?? 0.0;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await updateInventoryRow(
        widget.row,
        name: _name.text.trim(),
        variant: _variant.text.trim(),
        stockG: _n(_stock.text),
        sellPerKg: _n(_sellPerKg.text),
        costPerKg: _n(_costPerKg.text), // ✅ هتتخزن
        minLevelG: _n(_minLevel.text),
      );
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
}
