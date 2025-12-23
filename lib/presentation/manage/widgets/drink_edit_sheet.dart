import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import '../state/drinks_provider.dart';

class DrinkEditSheet extends StatefulWidget {
  final DrinkRow drink;
  const DrinkEditSheet({super.key, required this.drink});

  @override
  State<DrinkEditSheet> createState() => _DrinkEditSheetState();
}

class _DrinkEditSheetState extends State<DrinkEditSheet> {
  late final _name = TextEditingController(text: widget.drink.name);
  late final _unit = TextEditingController(text: widget.drink.unit);
  late final _sell = TextEditingController(
    text: widget.drink.sellPrice.toStringAsFixed(2),
  );
  late final _cost = TextEditingController(
    text: widget.drink.costPrice.toStringAsFixed(2),
  );
  // late final _img = TextEditingController(text: widget.drink.image);

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _sell.dispose();
    _cost.dispose();
    // _img.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await updateDrinkRow(
        widget.drink,
        name: _name.text.trim(),
        unit: _unit.text.trim().isEmpty ? 'cup' : _unit.text.trim(),
        sellPrice:
            double.tryParse(_sell.text.replaceAll(',', '.')) ??
            widget.drink.sellPrice,
        costPrice:
            double.tryParse(_cost.text.replaceAll(',', '.')) ??
            widget.drink.costPrice,
        // image: _img.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.saveSuccess)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
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
              AppStrings.editDrinkTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _tf(_name, AppStrings.nameLabel),
            const SizedBox(height: 8),
            _tf(_unit, AppStrings.unitCupBottleLabel),
            const SizedBox(height: 8),
            _tf(_sell, AppStrings.priceLabelDefinite),
            const SizedBox(height: 8),
            _tf(_cost, AppStrings.costLabelDefinite),
            // const SizedBox(height: 8),
            // _tf(_img, 'الصورة (اختياري)'),
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

  Widget _tf(TextEditingController c, String label) => TextField(
    controller: c,
    textAlign: TextAlign.center,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
