import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _OptionEntry {
  _OptionEntry(this.id, {String initial = ''})
    : controller = TextEditingController(text: initial);

  final String id;
  final TextEditingController controller;

  String get name => controller.text.trim();

  void dispose() {
    controller.dispose();
  }
}

class _DrinkPriceEntry {
  _DrinkPriceEntry({required this.variantId, required this.roastId})
    : sellCtrl = TextEditingController(text: '0.0'),
      costCtrl = TextEditingController(text: '0.0'),
      spicedSellCtrl = TextEditingController(text: '0.0'),
      spicedCostCtrl = TextEditingController(text: '0.0');

  final String variantId;
  final String roastId;
  final TextEditingController sellCtrl;
  final TextEditingController costCtrl;
  final TextEditingController spicedSellCtrl;
  final TextEditingController spicedCostCtrl;

  void dispose() {
    sellCtrl.dispose();
    costCtrl.dispose();
    spicedSellCtrl.dispose();
    spicedCostCtrl.dispose();
  }
}

class _RoastUsageEntry {
  _RoastUsageEntry() : gramsCtrl = TextEditingController();

  final TextEditingController gramsCtrl;
  final Map<String, TextEditingController> variantGramsCtrls = {};
  InventoryRow? item;
  String? coll;

  void syncVariants(Set<String> activeIds) {
    for (final id in activeIds) {
      variantGramsCtrls.putIfAbsent(id, () => TextEditingController());
    }
    final removeIds = variantGramsCtrls.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in removeIds) {
      variantGramsCtrls[id]?.dispose();
      variantGramsCtrls.remove(id);
    }
  }

  TextEditingController gramsFor(String variantId) {
    return variantGramsCtrls.putIfAbsent(
      variantId,
      () => TextEditingController(),
    );
  }

  void dispose() {
    gramsCtrl.dispose();
    for (final ctrl in variantGramsCtrls.values) {
      ctrl.dispose();
    }
  }
}

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
  static const _defaultVariantId = '_default_variant';
  static const _defaultRoastId = '_default_roast';

  late Map<String, dynamic> _data;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _variant = TextEditingController();
  final _unit = TextEditingController();
  final _stock = TextEditingController();

  final _sellPerKg = TextEditingController();
  final _costPerKg = TextEditingController();
  final _spicePricePerKg = TextEditingController();
  final _spiceCostPerKg = TextEditingController();
  final _ginsengPricePerKg = TextEditingController();
  final _ginsengCostPerKg = TextEditingController();
  bool _beanSpicedEnabled = false;
  bool _beanGinsengEnabled = false;

  final _sellPrice = TextEditingController();
  final _costPrice = TextEditingController();
  final _spicedPriceDelta = TextEditingController(text: '0.0');
  final _spicedCostDelta = TextEditingController(text: '0.0');
  bool _drinkSpicedEnabled = false;

  final _doublePrice = TextEditingController();
  final _doubleCost = TextEditingController();
  final _spicedCupCost = TextEditingController();
  final _spicedDoubleCupCost = TextEditingController();
  bool _showLegacyDrinkFields = false;

  final List<_OptionEntry> _drinkVariants = [];
  final List<_OptionEntry> _drinkRoasts = [];
  final Map<String, _DrinkPriceEntry> _drinkPrices = {};
  final Map<String, _RoastUsageEntry> _roastUsage = {};
  final Map<String, TextEditingController> _variantGrams = {};
  final _drinkUsedGrams = TextEditingController();
  InventoryRow? _drinkIngredient;
  String? _drinkIngredientColl;
  bool _showRoastUsageErrors = false;
  int _optionSeq = 0;

  bool _busy = false;

  bool get _isDrinks => widget.collection == 'drinks';

  @override
  void initState() {
    super.initState();
    _data = widget.snap.data() ?? <String, dynamic>{};
    _name.text = (_data['name'] ?? '').toString();
    _variant.text = (_data['variant'] ?? '').toString();
    _unit.text = (_data['unit'] ?? '').toString();
    final stock = _num(_data['stock']);
    if (stock > 0) _stock.text = _format(stock);

    if (_isDrinks) {
      _initDrinkFields();
    } else {
      _initBeanFields();
    }
  }

  void _initBeanFields() {
    _sellPerKg.text = _format(_num(_data['sellPricePerKg']));
    _costPerKg.text = _format(_num(_data['costPricePerKg']));
    final spicePrice = _num(_data['spicePricePerKg'] ?? _data['spicesPrice']);
    final spiceCost = _num(_data['spiceCostPerKg'] ?? _data['spicesCost']);
    _beanSpicedEnabled =
        (_data['spicedEnabled'] ?? false) == true ||
        spicePrice > 0 ||
        spiceCost > 0;
    _spicePricePerKg.text = _format(spicePrice);
    _spiceCostPerKg.text = _format(spiceCost);

    final ginsengPrice = _num(_data['ginsengPricePerKg']);
    final ginsengCost = _num(_data['ginsengCostPerKg']);
    _beanGinsengEnabled =
        (_data['ginsengEnabled'] ?? false) == true ||
        ginsengPrice > 0 ||
        ginsengCost > 0;
    _ginsengPricePerKg.text = _format(ginsengPrice);
    _ginsengCostPerKg.text = _format(ginsengCost);
  }

  void _initDrinkFields() {
    _sellPrice.text = _format(_num(_data['sellPrice']));
    _costPrice.text = _format(_num(_data['costPrice']));
    _drinkSpicedEnabled = (_data['spicedEnabled'] ?? false) == true;
    _spicedPriceDelta.text = _format(_num(_data['spicedPriceDelta']));
    _spicedCostDelta.text = _format(_num(_data['spicedCostDelta']));

    _doublePrice.text = _format(_num(_data['doublePrice']));
    _doubleCost.text = _format(_num(_data['doubleCost']));
    _spicedCupCost.text = _format(_num(_data['spicedCupCost']));
    _spicedDoubleCupCost.text = _format(_num(_data['spicedDoubleCupCost']));
    _showLegacyDrinkFields =
        _data.containsKey('doublePrice') ||
        _data.containsKey('doubleCost') ||
        _data.containsKey('spicedCupCost') ||
        _data.containsKey('spicedDoubleCupCost');

    for (final v in _stringList(_data['variants'])) {
      _drinkVariants.add(_OptionEntry(_nextOptionId(), initial: v));
    }
    for (final r in _stringList(_data['roastLevels'])) {
      _drinkRoasts.add(_OptionEntry(_nextOptionId(), initial: r));
    }

    _syncDrinkPricing();
    _applyDrinkPricing(_mapList(_data['pricing']));

    _syncRoastUsage();
    _applyRoastUsage(_mapList(_data['roastUsage']));

    final usedItem = _mapOrNull(_data['usedItem']);
    if (usedItem != null) {
      _drinkIngredient = _inventoryFromMap(usedItem);
      _drinkIngredientColl = usedItem['collection']?.toString();
    }
    final usedByVariant = _mapOrNull(_data['usedAmountByVariant']);
    if (usedByVariant != null && usedByVariant.isNotEmpty) {
      if (_drinkVariants.isNotEmpty) {
        _applyVariantUsage(usedByVariant);
      } else {
        _drinkUsedGrams.text = _format(_num(usedByVariant.values.first));
      }
    } else {
      final usedAmount = _num(_data['usedAmount']);
      if (usedAmount > 0) {
        if (_drinkVariants.isNotEmpty) {
          for (final variant in _drinkVariants) {
            _variantGrams[variant.id]?.text = _format(usedAmount);
          }
        } else {
          _drinkUsedGrams.text = _format(usedAmount);
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _unit.dispose();
    _stock.dispose();
    _sellPerKg.dispose();
    _costPerKg.dispose();
    _spicePricePerKg.dispose();
    _spiceCostPerKg.dispose();
    _ginsengPricePerKg.dispose();
    _ginsengCostPerKg.dispose();
    _sellPrice.dispose();
    _costPrice.dispose();
    _spicedPriceDelta.dispose();
    _spicedCostDelta.dispose();
    _doublePrice.dispose();
    _doubleCost.dispose();
    _spicedCupCost.dispose();
    _spicedDoubleCupCost.dispose();
    _drinkUsedGrams.dispose();
    for (final entry in _drinkVariants) {
      entry.dispose();
    }
    for (final entry in _drinkRoasts) {
      entry.dispose();
    }
    for (final entry in _drinkPrices.values) {
      entry.dispose();
    }
    for (final entry in _roastUsage.values) {
      entry.dispose();
    }
    for (final ctrl in _variantGrams.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = _isDrinks ? await _saveDrink() : await _saveBean();
      if (!ok || !mounted) return;
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

  Future<bool> _saveBean() async {
    final upd = <String, dynamic>{
      'name': _name.text.trim(),
      'variant': _variant.text.trim(),
    };
    if (_unit.text.trim().isNotEmpty) {
      upd['unit'] = _unit.text.trim();
    }
    upd['stock'] = _num(_stock.text);
    upd['sellPricePerKg'] = _num(_sellPerKg.text);
    upd['costPricePerKg'] = _num(_costPerKg.text);

    upd['spicedEnabled'] = _beanSpicedEnabled;
    final spicePrice = _beanSpicedEnabled ? _num(_spicePricePerKg.text) : 0.0;
    final spiceCost = _beanSpicedEnabled ? _num(_spiceCostPerKg.text) : 0.0;
    upd['spicePricePerKg'] = spicePrice;
    upd['spiceCostPerKg'] = spiceCost;
    upd['spicesPrice'] = spicePrice;
    upd['spicesCost'] = spiceCost;

    if (_beanGinsengEnabled) {
      upd['ginsengEnabled'] = true;
      upd['ginsengPricePerKg'] = _num(_ginsengPricePerKg.text);
      upd['ginsengCostPerKg'] = _num(_ginsengCostPerKg.text);
    } else {
      upd['ginsengEnabled'] = FieldValue.delete();
      upd['ginsengPricePerKg'] = FieldValue.delete();
      upd['ginsengCostPerKg'] = FieldValue.delete();
    }

    await widget.snap.reference.update(upd);
    return true;
  }

  Future<bool> _saveDrink() async {
    final variants = _drinkVariants.map((e) => e.name).toList();
    final roasts = _drinkRoasts.map((e) => e.name).toList();
    final hasVariants = variants.isNotEmpty;
    final hasMatrix = variants.isNotEmpty || roasts.isNotEmpty;
    final pricing = <Map<String, dynamic>>[];

    if (hasMatrix) {
      _syncDrinkPricing();
      final variantIds = _drinkVariants.isEmpty
          ? <String>[_defaultVariantId]
          : _drinkVariants.map((e) => e.id).toList();
      final roastIds = _drinkRoasts.isEmpty
          ? <String>[_defaultRoastId]
          : _drinkRoasts.map((e) => e.id).toList();

      for (final vId in variantIds) {
        for (final rId in roastIds) {
          final row = _drinkPrices[_priceKey(vId, rId)];
          if (row == null) continue;
          final entry = <String, dynamic>{
            'sellPrice': _num(row.sellCtrl.text),
            'costPrice': _num(row.costCtrl.text),
          };
          final variant = _variantNameFor(vId);
          final roast = _roastNameFor(rId);
          if (variant.isNotEmpty) entry['variant'] = variant;
          if (roast.isNotEmpty) entry['roast'] = roast;
          if (_drinkSpicedEnabled) {
            entry['spicedPriceDelta'] = _num(row.spicedSellCtrl.text);
            entry['spicedCostDelta'] = _num(row.spicedCostCtrl.text);
          }
          pricing.add(entry);
        }
      }
    }

    double baseSell = _num(_sellPrice.text);
    double baseCost = _num(_costPrice.text);
    if (hasMatrix && pricing.isNotEmpty) {
      baseSell = _num(pricing.first['sellPrice']);
      baseCost = _num(pricing.first['costPrice']);
    }

    final upd = <String, dynamic>{
      'name': _name.text.trim(),
      'unit': _unit.text.trim().isEmpty ? 'cup' : _unit.text.trim(),
      'sellPrice': baseSell,
      'costPrice': baseCost,
      'variants': variants,
      'roastLevels': roasts,
      'spicedEnabled': _drinkSpicedEnabled,
    };
    final stockTxt = _stock.text.trim();
    if (stockTxt.isNotEmpty) {
      upd['stock'] = _num(_stock.text);
    }

    if (hasMatrix && pricing.isNotEmpty) {
      upd['pricing'] = pricing;
    } else {
      upd['pricing'] = FieldValue.delete();
    }

    if (!hasMatrix && _drinkSpicedEnabled) {
      upd['spicedPriceDelta'] = _num(_spicedPriceDelta.text);
      upd['spicedCostDelta'] = _num(_spicedCostDelta.text);
    } else {
      upd['spicedPriceDelta'] = FieldValue.delete();
      upd['spicedCostDelta'] = FieldValue.delete();
    }

    if (roasts.isNotEmpty) {
      _syncRoastUsage();
      final missingItem = _drinkRoasts.any(
        (roast) => _roastUsage[roast.id]?.item == null,
      );
      if (missingItem) {
        setState(() => _showRoastUsageErrors = true);
        return false;
      } else if (_showRoastUsageErrors) {
        setState(() => _showRoastUsageErrors = false);
      }

      final roastUsage = <Map<String, dynamic>>[];
      for (final roast in _drinkRoasts) {
        final usage = _roastUsage[roast.id]!;
        final item = usage.item!;
        final entry = <String, dynamic>{
          'roast': roast.name,
          'usedItem': {
            'id': item.id,
            'name': item.name,
            'variant': item.variant,
            'collection': usage.coll ?? item.coll,
          },
        };
        if (hasVariants) {
          final usedAmounts = <String, double>{};
          for (final variant in _drinkVariants) {
            usedAmounts[variant.name] = _num(usage.gramsFor(variant.id).text);
          }
          if (usedAmounts.isNotEmpty) {
            entry['usedAmounts'] = usedAmounts;
            entry['usedAmount'] = usedAmounts.values.first;
          }
        } else {
          entry['usedAmount'] = _num(usage.gramsCtrl.text);
        }
        roastUsage.add(entry);
      }
      upd['roastUsage'] = roastUsage;
      upd['usedItem'] = FieldValue.delete();
      upd['usedAmount'] = FieldValue.delete();
      upd['usedAmountByVariant'] = FieldValue.delete();
    } else {
      final usedItem = _drinkIngredient;
      if (usedItem != null) {
        upd['usedItem'] = {
          'id': usedItem.id,
          'name': usedItem.name,
          'variant': usedItem.variant,
          'collection': _drinkIngredientColl ?? usedItem.coll,
        };
      } else {
        upd['usedItem'] = FieldValue.delete();
      }
      if (hasVariants) {
        final usedByVariant = <String, double>{};
        for (final variant in _drinkVariants) {
          final grams = _num(_variantGrams[variant.id]?.text);
          if (grams > 0) {
            usedByVariant[variant.name] = grams;
          }
        }
        if (usedByVariant.isNotEmpty) {
          upd['usedAmountByVariant'] = usedByVariant;
          upd['usedAmount'] = usedByVariant.values.first;
        } else {
          upd['usedAmountByVariant'] = FieldValue.delete();
          upd['usedAmount'] = FieldValue.delete();
        }
      } else {
        final usedAmount = _num(_drinkUsedGrams.text);
        if (usedAmount > 0) {
          upd['usedAmount'] = usedAmount;
        } else {
          upd['usedAmount'] = FieldValue.delete();
        }
        upd['usedAmountByVariant'] = FieldValue.delete();
      }
      upd['roastUsage'] = FieldValue.delete();
    }

    if (_showLegacyDrinkFields) {
      upd['doublePrice'] = _num(_doublePrice.text);
      upd['doubleCost'] = _num(_doubleCost.text);
      upd['spicedCupCost'] = _num(_spicedCupCost.text);
      upd['spicedDoubleCupCost'] = _num(_spicedDoubleCupCost.text);
    }

    await widget.snap.reference.update(upd);
    return true;
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
              _isDrinks ? AppStrings.editDrinkTitle : AppStrings.editItemTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _tf(
              _name,
              AppStrings.nameLabel,
              TextInputType.text,
              validator: (v) => _requiredText(v, AppStrings.nameRequiredPrompt),
            ),
            if (!_isDrinks) ...[
              const SizedBox(height: 8),
              _tf(_variant, AppStrings.roastVariantLabel, TextInputType.text),
            ],
            const SizedBox(height: 8),
            _tf(
              _unit,
              _isDrinks
                  ? AppStrings.unitCupBottleLabel
                  : AppStrings.unitOptionalLabel,
              TextInputType.text,
            ),
            const SizedBox(height: 12),
            _tf(
              _stock,
              _isDrinks
                  ? AppStrings.stockOptionalLabel
                  : AppStrings.stockGramsShortLabel,
              const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            if (_isDrinks) ...[
              _buildDrinkVariantsSection(),
              const SizedBox(height: 10),
              _buildDrinkRoastsSection(),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: CheckboxListTile(
                  value: _drinkSpicedEnabled,
                  onChanged: (v) =>
                      setState(() => _drinkSpicedEnabled = v ?? false),
                  title: const Text(AppStrings.spicedOptionLabel),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              _buildDrinkPricingSection(),
              const SizedBox(height: 12),
              _buildDrinkIngredientSection(),
              if (_showLegacyDrinkFields) ...[
                const SizedBox(height: 12),
                // _tf(
                //   _doublePrice,
                //   AppStrings.doublePriceLabel,
                //   const TextInputType.numberWithOptions(decimal: true),
                // ),
                // const SizedBox(height: 8),
                // _tf(
                //   _doubleCost,
                //   AppStrings.doubleCostLabel,
                //   const TextInputType.numberWithOptions(decimal: true),
                // ),
                // const SizedBox(height: 8),
                // _tf(
                //   _spicedCupCost,
                //   AppStrings.spicedCupCostLabel,
                //   const TextInputType.numberWithOptions(decimal: true),
                // ),
                // const SizedBox(height: 8),
                // _tf(
                //   _spicedDoubleCupCost,
                //   AppStrings.spicedDoubleCostLabel,
                //   const TextInputType.numberWithOptions(decimal: true),
                // ),
              ],
            ] else ...[
              _tf(
                _sellPerKg,
                AppStrings.pricePerKgLabel,
                const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    _requiredPositive(v, AppStrings.sellPriceRequiredPrompt),
              ),
              const SizedBox(height: 8),
              _tf(
                _costPerKg,
                AppStrings.costPerKgLabel,
                const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    _requiredPositive(v, AppStrings.costPriceRequiredPrompt),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: CheckboxListTile(
                  value: _beanSpicedEnabled,
                  onChanged: (v) =>
                      setState(() => _beanSpicedEnabled = v ?? false),
                  title: const Text(AppStrings.spicedOptionLabel),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              if (_beanSpicedEnabled) ...[
                _tf(
                  _spicePricePerKg,
                  AppStrings.spicePricePerKgLabel,
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _requiredPositive(
                    v,
                    AppStrings.spicePriceCostRequiredPrompt,
                  ),
                ),
                const SizedBox(height: 8),
                _tf(
                  _spiceCostPerKg,
                  AppStrings.spiceCostPerKgLabel,
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _requiredPositive(
                    v,
                    AppStrings.spicePriceCostRequiredPrompt,
                  ),
                ),
              ],
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: CheckboxListTile(
                  value: _beanGinsengEnabled,
                  onChanged: (v) =>
                      setState(() => _beanGinsengEnabled = v ?? false),
                  title: const Text(AppStrings.ginsengOptionLabel),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              if (_beanGinsengEnabled) ...[
                _tf(
                  _ginsengPricePerKg,
                  AppStrings.ginsengPricePerKgLabel,
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _requiredPositive(
                    v,
                    AppStrings.ginsengPriceCostRequiredPrompt,
                  ),
                ),
                const SizedBox(height: 8),
                _tf(
                  _ginsengCostPerKg,
                  AppStrings.ginsengCostPerKgLabel,
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _requiredPositive(
                    v,
                    AppStrings.ginsengPriceCostRequiredPrompt,
                  ),
                ),
              ],
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
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String actionLabel,
    VoidCallback onTap,
  ) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }

  Widget _buildDrinkVariantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          AppStrings.drinkVariantsLabel,
          AppStrings.addVariantLabel,
          () => setState(() {
            _drinkVariants.add(_OptionEntry(_nextOptionId()));
            _syncDrinkPricing();
          }),
        ),
        if (_drinkVariants.isEmpty)
          Text(
            AppStrings.drinkVariantsHint,
            style: TextStyle(color: Colors.brown.shade300),
          )
        else
          ..._drinkVariants.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: entry.controller,
                      textAlign: TextAlign.center,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) =>
                          _requiredText(v, AppStrings.fillVariantNamesPrompt),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: AppStrings.variantNameLabel,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        _drinkVariants.remove(entry);
                        entry.dispose();
                        _syncDrinkPricing();
                      });
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDrinkRoastsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          AppStrings.drinkRoastsLabel,
          AppStrings.addRoastLabel,
          () => setState(() {
            _drinkRoasts.add(_OptionEntry(_nextOptionId()));
            _syncDrinkPricing();
            _syncRoastUsage();
          }),
        ),
        if (_drinkRoasts.isEmpty)
          Text(
            AppStrings.drinkRoastsHint,
            style: TextStyle(color: Colors.brown.shade300),
          )
        else
          ..._drinkRoasts.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: entry.controller,
                      textAlign: TextAlign.center,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) =>
                          _requiredText(v, AppStrings.fillRoastNamesPrompt),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        labelText: AppStrings.roastNameLabel,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        _drinkRoasts.remove(entry);
                        entry.dispose();
                        _syncDrinkPricing();
                        _syncRoastUsage();
                      });
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDrinkPricingSection() {
    final hasMatrix = _drinkVariants.isNotEmpty || _drinkRoasts.isNotEmpty;
    final numKeyboard = const TextInputType.numberWithOptions(decimal: true);

    if (!hasMatrix) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.drinkPricingLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _tf(
            _sellPrice,
            AppStrings.cupPriceLabel,
            numKeyboard,
            validator: (v) =>
                _requiredPositive(v, AppStrings.sellPriceRequiredPrompt),
          ),
          const SizedBox(height: 8),
          _tf(
            _costPrice,
            AppStrings.cupCostLabel,
            numKeyboard,
            validator: (v) =>
                _requiredPositive(v, AppStrings.costPriceRequiredPrompt),
          ),
          if (_drinkSpicedEnabled) ...[
            const SizedBox(height: 8),
            _tf(
              _spicedPriceDelta,
              AppStrings.spicedExtraPriceLabel,
              numKeyboard,
            ),
            const SizedBox(height: 8),
            _tf(_spicedCostDelta, AppStrings.spicedExtraCostLabel, numKeyboard),
          ],
        ],
      );
    }

    final rows = _orderedDrinkPrices();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.drinkPricingLabel,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...rows.map((row) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.brown.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _priceLabelFor(row),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _tf(
                          row.sellCtrl,
                          AppStrings.sellPriceLabel,
                          numKeyboard,
                          validator: (v) => _requiredPositive(
                            v,
                            AppStrings.sellPriceRequiredPrompt,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _tf(
                          row.costCtrl,
                          AppStrings.costLabelDefinite,
                          numKeyboard,
                          validator: (v) => _requiredPositive(
                            v,
                            AppStrings.costPriceRequiredPrompt,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_drinkSpicedEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _tf(
                            row.spicedSellCtrl,
                            AppStrings.spicedExtraPriceLabel,
                            numKeyboard,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _tf(
                            row.spicedCostCtrl,
                            AppStrings.spicedExtraCostLabel,
                            numKeyboard,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDrinkIngredientSection() {
    final inventoryState = context.watch<InventoryCubit>().state;
    final hasRoasts = _drinkRoasts.isNotEmpty;
    final hasVariants = _drinkVariants.isNotEmpty;
    final numKeyboard = const TextInputType.numberWithOptions(decimal: true);

    List<Widget> buildVariantGramsFields(
      TextEditingController Function(String) controllerFor, {
      bool required = false,
    }) {
      final fields = <Widget>[];
      for (final variant in _drinkVariants) {
        if (fields.isNotEmpty) {
          fields.add(const SizedBox(height: 8));
        }
        final label = variant.name.isEmpty
            ? AppStrings.unnamedLabel
            : variant.name;
        fields.add(
          _tf(
            controllerFor(variant.id),
            '${AppStrings.usedGramsLabel} ($label)',
            numKeyboard,
            validator: required
                ? (v) =>
                      _requiredPositive(v, AppStrings.fillRoastUsageGramsPrompt)
                : null,
          ),
        );
      }
      return fields;
    }

    if (hasRoasts) {
      _syncRoastUsage();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.roastUsageLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ..._drinkRoasts.map((roast) {
            final usage = _roastUsageFor(roast.id);
            final showItemError = _showRoastUsageErrors && usage.item == null;
            final itemName = usage.item == null
                ? AppStrings.noIngredientSelectedLabel
                : (usage.item!.variant.isEmpty
                      ? usage.item!.name
                      : '${usage.item!.name} - ${usage.item!.variant}');
            final roastName = roast.name.isEmpty
                ? AppStrings.unnamedLabel
                : roast.name;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: showItemError
                      ? Colors.red.shade300
                      : Colors.brown.shade100,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            roastName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (usage.item != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                usage.item = null;
                                usage.coll = null;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      itemName,
                      style: TextStyle(color: Colors.brown.shade600),
                    ),
                    if (showItemError) ...[
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.fillRoastUsagePrompt,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text(AppStrings.pickSingleItem),
                            onPressed: () async {
                              final chosen = await _showIngredientPicker(
                                coll: 'singles',
                                source: inventoryState.singles,
                                loading: inventoryState.loadingSingles,
                              );
                              if (!mounted || chosen == null) return;
                              setState(() {
                                usage.item = chosen;
                                usage.coll = 'singles';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text(AppStrings.pickBlend),
                            onPressed: () async {
                              final chosen = await _showIngredientPicker(
                                coll: 'blends',
                                source: inventoryState.blends,
                                loading: inventoryState.loadingBlends,
                              );
                              if (!mounted || chosen == null) return;
                              setState(() {
                                usage.item = chosen;
                                usage.coll = 'blends';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasVariants)
                      ...buildVariantGramsFields(usage.gramsFor, required: true)
                    else
                      _tf(
                        usage.gramsCtrl,
                        AppStrings.usedGramsLabel,
                        numKeyboard,
                        validator: (v) => _requiredPositive(
                          v,
                          AppStrings.fillRoastUsageGramsPrompt,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    final name = _drinkIngredient == null
        ? AppStrings.noIngredientSelectedLabel
        : (_drinkIngredient!.variant.isEmpty
              ? _drinkIngredient!.name
              : '${_drinkIngredient!.name} - ${_drinkIngredient!.variant}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.drinkIngredientLabel,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.pickSingleItem),
                onPressed: () => _pickDrinkIngredient(
                  coll: 'singles',
                  source: inventoryState.singles,
                  loading: inventoryState.loadingSingles,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.pickBlend),
                onPressed: () => _pickDrinkIngredient(
                  coll: 'blends',
                  source: inventoryState.blends,
                  loading: inventoryState.loadingBlends,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.brown.shade100),
          ),
          child: ListTile(
            title: Text(name, overflow: TextOverflow.ellipsis),
            subtitle: _drinkIngredientColl == null
                ? null
                : Text(
                    _drinkIngredientColl == 'singles'
                        ? AppStrings.singleLabel
                        : AppStrings.blendLabel,
                  ),
            trailing: _drinkIngredient == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _drinkIngredient = null;
                        _drinkIngredientColl = null;
                      });
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        if (hasVariants)
          ...buildVariantGramsFields(
            (id) =>
                _variantGrams.putIfAbsent(id, () => TextEditingController()),
          )
        else
          _tf(_drinkUsedGrams, AppStrings.usedGramsLabel, numKeyboard),
      ],
    );
  }

  Future<InventoryRow?> _showIngredientPicker({
    required String coll,
    required List<InventoryRow> source,
    required bool loading,
  }) async {
    return showDialog<InventoryRow>(
      context: context,
      builder: (_) {
        final search = TextEditingController();
        return AlertDialog(
          title: Text(
            coll == 'singles'
                ? AppStrings.pickSingleItem
                : AppStrings.pickBlend,
          ),
          content: SizedBox(
            width: 460,
            height: 520,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: AppStrings.searchByNameVariant,
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => (context as Element).markNeedsBuild(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(
                          builder: (context) {
                            final q = search.text.trim().toLowerCase();
                            final filtered = q.isEmpty
                                ? source
                                : source.where((r) {
                                    final t = '${r.name} ${r.variant}'
                                        .toLowerCase();
                                    return t.contains(q);
                                  }).toList();
                            if (filtered.isEmpty) {
                              return const Center(
                                child: Text(AppStrings.noResults),
                              );
                            }
                            return ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final r = filtered[i];
                                return ListTile(
                                  title: Text(
                                    r.variant.isEmpty
                                        ? r.name
                                        : '${r.name} - ${r.variant}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Wrap(
                                    spacing: 8,
                                    children: [
                                      Text(
                                        AppStrings.stockGramsInline(r.stockG),
                                      ),
                                      Text(
                                        AppStrings.pricePerKgInline(
                                          r.sellPerKg,
                                        ),
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
              child: const Text(AppStrings.actionCancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDrinkIngredient({
    required String coll,
    required List<InventoryRow> source,
    required bool loading,
  }) async {
    final chosen = await _showIngredientPicker(
      coll: coll,
      source: source,
      loading: loading,
    );

    if (!mounted) return;
    if (chosen != null) {
      setState(() {
        _drinkIngredient = chosen;
        _drinkIngredientColl = coll;
      });
    }
  }

  void _syncVariantUsage() {
    final activeIds = _drinkVariants.map((e) => e.id).toSet();
    for (final id in activeIds) {
      _variantGrams.putIfAbsent(id, () => TextEditingController());
    }
    final removeIds = _variantGrams.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in removeIds) {
      _variantGrams[id]?.dispose();
      _variantGrams.remove(id);
    }
    for (final entry in _roastUsage.values) {
      entry.syncVariants(activeIds);
    }
  }

  void _syncDrinkPricing() {
    _syncVariantUsage();
    if (_drinkVariants.isEmpty && _drinkRoasts.isEmpty) {
      _clearDrinkPrices();
      return;
    }

    final variantIds = _drinkVariants.isEmpty
        ? <String>[_defaultVariantId]
        : _drinkVariants.map((e) => e.id).toList();
    final roastIds = _drinkRoasts.isEmpty
        ? <String>[_defaultRoastId]
        : _drinkRoasts.map((e) => e.id).toList();

    final wantedKeys = <String>{};
    for (final v in variantIds) {
      for (final r in roastIds) {
        final key = _priceKey(v, r);
        wantedKeys.add(key);
        _drinkPrices.putIfAbsent(
          key,
          () => _DrinkPriceEntry(variantId: v, roastId: r),
        );
      }
    }

    final removeKeys = _drinkPrices.keys
        .where((k) => !wantedKeys.contains(k))
        .toList();
    for (final key in removeKeys) {
      _drinkPrices[key]?.dispose();
      _drinkPrices.remove(key);
    }
  }

  void _clearDrinkPrices() {
    for (final entry in _drinkPrices.values) {
      entry.dispose();
    }
    _drinkPrices.clear();
  }

  void _syncRoastUsage() {
    final activeIds = _drinkRoasts.map((e) => e.id).toSet();
    for (final id in activeIds) {
      _roastUsage.putIfAbsent(id, () => _RoastUsageEntry());
    }
    final removeIds = _roastUsage.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in removeIds) {
      _roastUsage[id]?.dispose();
      _roastUsage.remove(id);
    }
    final variantIds = _drinkVariants.map((e) => e.id).toSet();
    for (final entry in _roastUsage.values) {
      entry.syncVariants(variantIds);
    }
  }

  void _applyDrinkPricing(List<Map<String, dynamic>> pricing) {
    if (pricing.isEmpty || _drinkPrices.isEmpty) return;
    for (final entry in _drinkPrices.values) {
      final variant = _variantNameFor(entry.variantId);
      final roast = _roastNameFor(entry.roastId);
      final match = _findPricing(pricing, variant, roast);
      if (match == null) continue;
      entry.sellCtrl.text = _format(_num(match['sellPrice']));
      entry.costCtrl.text = _format(_num(match['costPrice']));
      entry.spicedSellCtrl.text = _format(_num(match['spicedPriceDelta']));
      entry.spicedCostCtrl.text = _format(_num(match['spicedCostDelta']));
    }
  }

  void _applyRoastUsage(List<Map<String, dynamic>> usage) {
    if (usage.isEmpty || _drinkRoasts.isEmpty) return;
    for (final entry in usage) {
      final roastName = (entry['roast'] ?? '').toString();
      final roast = _findRoastByName(roastName);
      if (roast == null) continue;
      final usageEntry = _roastUsageFor(roast.id);
      final usedAmounts = _mapOrNull(entry['usedAmounts']);
      if (usedAmounts != null && usedAmounts.isNotEmpty) {
        if (_drinkVariants.isNotEmpty) {
          for (final usedEntry in usedAmounts.entries) {
            final variant = _findVariantByName(usedEntry.key);
            if (variant == null) continue;
            usageEntry.gramsFor(variant.id).text = _format(
              _num(usedEntry.value),
            );
          }
        } else {
          usageEntry.gramsCtrl.text = _format(_num(usedAmounts.values.first));
        }
      } else {
        final usedAmount = _num(entry['usedAmount']);
        if (_drinkVariants.isNotEmpty) {
          if (usedAmount > 0) {
            for (final variant in _drinkVariants) {
              usageEntry.gramsFor(variant.id).text = _format(usedAmount);
            }
          }
        } else if (usedAmount > 0) {
          usageEntry.gramsCtrl.text = _format(usedAmount);
        }
      }
      final usedItem = _mapOrNull(entry['usedItem']);
      if (usedItem != null) {
        usageEntry.item = _inventoryFromMap(usedItem);
        usageEntry.coll = usedItem['collection']?.toString();
      }
    }
  }

  void _applyVariantUsage(Map<String, dynamic> usage) {
    if (usage.isEmpty || _drinkVariants.isEmpty) return;
    for (final entry in usage.entries) {
      final variant = _findVariantByName(entry.key);
      if (variant == null) continue;
      _variantGrams[variant.id]?.text = _format(_num(entry.value));
    }
  }

  _RoastUsageEntry _roastUsageFor(String roastId) {
    return _roastUsage.putIfAbsent(roastId, () => _RoastUsageEntry());
  }

  List<_DrinkPriceEntry> _orderedDrinkPrices() {
    if (_drinkVariants.isEmpty && _drinkRoasts.isEmpty) {
      return const [];
    }
    final variantIds = _drinkVariants.isEmpty
        ? <String>[_defaultVariantId]
        : _drinkVariants.map((e) => e.id).toList();
    final roastIds = _drinkRoasts.isEmpty
        ? <String>[_defaultRoastId]
        : _drinkRoasts.map((e) => e.id).toList();

    final rows = <_DrinkPriceEntry>[];
    for (final v in variantIds) {
      for (final r in roastIds) {
        final row = _drinkPrices[_priceKey(v, r)];
        if (row != null) rows.add(row);
      }
    }
    return rows;
  }

  String _variantNameFor(String id) {
    if (id == _defaultVariantId) return '';
    for (final entry in _drinkVariants) {
      if (entry.id == id) return entry.name;
    }
    return '';
  }

  String _roastNameFor(String id) {
    if (id == _defaultRoastId) return '';
    for (final entry in _drinkRoasts) {
      if (entry.id == id) return entry.name;
    }
    return '';
  }

  String _priceLabelFor(_DrinkPriceEntry row) {
    final variant = _variantNameFor(row.variantId);
    final roast = _roastNameFor(row.roastId);
    final hasVariants = _drinkVariants.isNotEmpty;
    final hasRoasts = _drinkRoasts.isNotEmpty;
    if (hasVariants && hasRoasts) {
      final v = variant.isEmpty ? AppStrings.unnamedLabel : variant;
      final r = roast.isEmpty ? AppStrings.unnamedLabel : roast;
      return '$v - $r';
    }
    if (hasVariants) {
      return variant.isEmpty ? AppStrings.unnamedLabel : variant;
    }
    if (hasRoasts) {
      return roast.isEmpty ? AppStrings.unnamedLabel : roast;
    }
    return AppStrings.drinkPricingLabel;
  }

  String _nextOptionId() => 'opt_${_optionSeq++}';

  String _priceKey(String variantId, String roastId) => '$variantId::$roastId';

  _OptionEntry? _findVariantByName(String name) {
    for (final entry in _drinkVariants) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  _OptionEntry? _findRoastByName(String name) {
    for (final entry in _drinkRoasts) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  Map<String, dynamic>? _findPricing(
    List<Map<String, dynamic>> pricing,
    String variant,
    String roast,
  ) {
    for (final entry in pricing) {
      final entryVariant = (entry['variant'] ?? '').toString();
      final entryRoast = (entry['roast'] ?? '').toString();
      if (entryVariant == variant && entryRoast == roast) {
        return entry;
      }
    }
    if (variant.isEmpty && roast.isEmpty && pricing.length == 1) {
      return pricing.first;
    }
    return null;
  }

  InventoryRow _inventoryFromMap(Map<String, dynamic> data) {
    final id = (data['id'] ?? '').toString();
    final name = (data['name'] ?? '').toString();
    final variant = (data['variant'] ?? '').toString();
    final coll = (data['collection'] ?? '').toString();
    final refColl = coll.isEmpty ? 'singles' : coll;
    return InventoryRow(
      id: id,
      name: name,
      variant: variant,
      stockG: 0,
      minLevelG: 0,
      sellPerKg: 0,
      costPerKg: 0,
      coll: coll,
      ref: FirebaseFirestore.instance.collection(refColl).doc(id),
    );
  }

  List<String> _stringList(dynamic raw) {
    if (raw is Iterable) {
      final values = <String>[];
      for (final entry in raw) {
        if (entry == null) continue;
        final value = entry.toString().trim();
        if (value.isEmpty) continue;
        values.add(value);
      }
      return values;
    }
    return const [];
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic>? _mapOrNull(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  String _format(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  Widget _tf(
    TextEditingController c,
    String label,
    TextInputType kt, {
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: c,
      textAlign: TextAlign.center,
      keyboardType: kt,
      autovalidateMode: validator == null
          ? AutovalidateMode.disabled
          : AutovalidateMode.onUserInteraction,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
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
