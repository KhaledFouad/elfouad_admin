import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';
import 'package:elfouad_admin/presentation/inventory/utils/inventory_log.dart';
import 'package:elfouad_admin/presentation/manage/bloc/extras_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum NewItemType { single, blend, drink, extra }

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

class _ItemRoastEntry {
  _ItemRoastEntry(this.id)
    : nameCtrl = TextEditingController(),
      stockCtrl = TextEditingController(text: '0'),
      sellCtrl = TextEditingController(text: '0.0'),
      costCtrl = TextEditingController(text: '0.0');

  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController sellCtrl;
  final TextEditingController costCtrl;

  String get name => nameCtrl.text.trim();

  void dispose() {
    nameCtrl.dispose();
    stockCtrl.dispose();
    sellCtrl.dispose();
    costCtrl.dispose();
  }
}

class AddItemSheet extends StatefulWidget {
  final NewItemType initialType;

  const AddItemSheet({super.key, this.initialType = NewItemType.blend});
  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  static const _defaultVariantId = '_default_variant';
  static const _defaultRoastId = '_default_roast';

  late NewItemType _t;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _posOrder = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _category = TextEditingController();
  final _extraUnit = TextEditingController(text: 'piece');
  final List<_ItemRoastEntry> _itemRoasts = [];
  final _baseSellPerKg = TextEditingController(text: '0.0');
  final _baseCostPerKg = TextEditingController(text: '0.0');
  final _spicePricePerKg = TextEditingController(text: '0.0');
  final _spiceCostPerKg = TextEditingController(text: '0.0');
  final _ginsengPricePerKg = TextEditingController(text: '0.0');
  final _ginsengCostPerKg = TextEditingController(text: '0.0');
  bool _itemSpicedEnabled = false;
  bool _itemGinsengEnabled = false;
  // ┘ê╪▓┘å/╪│╪╣╪▒/╪¬┘â┘ä┘ü╪⌐

  // drinks
  final _sellCup = TextEditingController(text: '0.0');
  final _costCup = TextEditingController(text: '0.0'); // Γ£à
  final _drinkSpicedPrice = TextEditingController(text: '0.0');
  final _drinkSpicedCost = TextEditingController(text: '0.0');
  final _extraPrice = TextEditingController(text: '0.0');
  final _extraCost = TextEditingController(text: '0.0');
  bool _extraActive = true;
  final List<_OptionEntry> _drinkVariants = [];
  final List<_OptionEntry> _drinkRoasts = [];
  final Map<String, _DrinkPriceEntry> _drinkPrices = {};
  final Map<String, _RoastUsageEntry> _roastUsage = {};
  final Map<String, TextEditingController> _variantGrams = {};
  final _drinkUsedGrams = TextEditingController();
  InventoryRow? _drinkIngredient;
  String? _drinkIngredientColl;
  bool _drinkSpicedEnabled = false;
  bool _showRoastUsageErrors = false;
  int _optionSeq = 0;

  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _t = widget.initialType;
  }

  @override
  void dispose() {
    _name.dispose();
    _posOrder.dispose();
    _stock.dispose();
    _baseSellPerKg.dispose();
    _baseCostPerKg.dispose();
    _spicePricePerKg.dispose();
    _spiceCostPerKg.dispose();
    _ginsengPricePerKg.dispose();
    _ginsengCostPerKg.dispose();
    _sellCup.dispose();
    _costCup.dispose();
    _drinkSpicedPrice.dispose();
    _drinkSpicedCost.dispose();
    _category.dispose();
    _extraUnit.dispose();
    _extraPrice.dispose();
    _extraCost.dispose();
    _drinkUsedGrams.dispose();
    for (final entry in _itemRoasts) {
      entry.dispose();
    }
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

  @override
  Widget build(BuildContext context) {
    final extrasState = context.watch<ExtrasCubit>().state;
    final categoryText = _category.text.trim().toLowerCase();
    final categoryExists =
        _t == NewItemType.extra &&
        categoryText.isNotEmpty &&
        extrasState.items.any(
          (e) => e.category.trim().toLowerCase() == categoryText,
        );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
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
              const Text(
                AppStrings.addNewItemTitle,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 10),

              // ╪¬╪¿┘ê┘è╪¿ ╪º┘ä╪ú┘å┘ê╪º╪╣
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
                onSelectionChanged: (s) {
                  setState(() {
                    _t = s.first;
                  });
                },
              ),
              const SizedBox(height: 10),

              // ≡ƒƒñ ┘â┘è╪¿┘ê╪▒╪» ┘å╪╡┘è ┘ä╪º╪│┘à/╪¬╪¡┘à┘è╪╡
              _tf(
                _name,
                AppStrings.nameLabel,
                TextInputType.text,
                validator: (v) =>
                    _requiredText(v, AppStrings.nameRequiredPrompt),
              ),
              const SizedBox(height: 8),
              _tf(
                _posOrder,
                AppStrings.posOrderLabel,
                const TextInputType.numberWithOptions(decimal: false),
                validator: (v) =>
                    _optionalInt(v, AppStrings.posOrderInvalidPrompt),
              ),
              const SizedBox(height: 8),
              if (_t == NewItemType.extra) ...[
                _tf(
                  _category,
                  AppStrings.categoryLabel,
                  TextInputType.text,
                  validator: (v) =>
                      _requiredText(v, AppStrings.categoryRequiredPrompt),
                  helperText: categoryExists
                      ? AppStrings.categoryExistsWarning
                      : null,
                  helperStyle: categoryExists
                      ? TextStyle(color: Colors.orange.shade700)
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _tf(
                  _extraUnit,
                  AppStrings.unitExampleLabel,
                  TextInputType.text,
                ),
                const SizedBox(height: 8),
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
                  validator: (v) =>
                      _requiredPositive(v, AppStrings.sellPriceRequiredPrompt),
                ),
                const SizedBox(height: 8),
                _tf(
                  _extraCost,
                  AppStrings.costPerUnitShortLabel,
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      _requiredPositive(v, AppStrings.costPriceRequiredPrompt),
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
              ] else if (_t == NewItemType.drink) ...[
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
              ] else ...[
                _buildItemRoastsSection(),
                const SizedBox(height: 8),
                if (_itemRoasts.isEmpty) ...[
                  _tf(
                    _stock,
                    AppStrings.stockGramsLabel,
                    const TextInputType.numberWithOptions(decimal: false),
                  ),
                  const SizedBox(height: 8),
                  _tf(
                    _baseSellPerKg,
                    AppStrings.pricePerKgLabelDefinite,
                    const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => _requiredPositive(
                      v,
                      AppStrings.sellPriceRequiredPrompt,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _tf(
                    _baseCostPerKg,
                    AppStrings.costPerKgLabel,
                    const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => _requiredPositive(
                      v,
                      AppStrings.costPriceRequiredPrompt,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CheckboxListTile(
                    value: _itemSpicedEnabled,
                    onChanged: (v) =>
                        setState(() => _itemSpicedEnabled = v ?? false),
                    title: const Text(AppStrings.spicedOptionLabel),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                if (_itemSpicedEnabled) ...[
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
                    value: _itemGinsengEnabled,
                    onChanged: (v) =>
                        setState(() => _itemGinsengEnabled = v ?? false),
                    title: const Text(AppStrings.ginsengOptionLabel),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                if (_itemGinsengEnabled) ...[
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
      ),
    );
  }

  Widget _tf(
    TextEditingController c,
    String label,
    TextInputType kt, {
    String? helperText,
    TextStyle? helperStyle,
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
        helperText: helperText,
        helperStyle: helperStyle,
      ),
    );
  }

  String _nextOptionId() => 'opt_${_optionSeq++}';

  String _priceKey(String variantId, String roastId) => '$variantId::$roastId';

  void _clearDrinkPrices() {
    for (final entry in _drinkPrices.values) {
      entry.dispose();
    }
    _drinkPrices.clear();
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
    final hasVariants = _drinkVariants.isNotEmpty;
    final hasRoasts = _drinkRoasts.isNotEmpty;
    final variant = _variantNameFor(row.variantId);
    final roast = _roastNameFor(row.roastId);

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

  Widget _buildItemRoastsSection() {
    final numKeyboard = const TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          AppStrings.drinkRoastsLabel,
          AppStrings.addRoastLabel,
          () => setState(() {
            _itemRoasts.add(_ItemRoastEntry(_nextOptionId()));
          }),
        ),
        if (_itemRoasts.isEmpty)
          Text(
            AppStrings.drinkRoastsHint,
            style: TextStyle(color: Colors.brown.shade300),
          )
        else
          ..._itemRoasts.map((entry) {
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
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: entry.nameCtrl,
                            textAlign: TextAlign.center,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (v) => _requiredText(
                              v,
                              AppStrings.fillRoastNamesPrompt,
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              labelText: AppStrings.roastNameLabel,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() {
                              _itemRoasts.remove(entry);
                              entry.dispose();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _tf(
                      entry.stockCtrl,
                      AppStrings.stockGramsLabel,
                      numKeyboard,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _tf(
                            entry.sellCtrl,
                            AppStrings.pricePerKgLabelDefinite,
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
                            entry.costCtrl,
                            AppStrings.costPerKgLabel,
                            numKeyboard,
                            validator: (v) => _requiredPositive(
                              v,
                              AppStrings.costPriceRequiredPrompt,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
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
            _sellCup,
            AppStrings.cupPriceLabel,
            numKeyboard,
            validator: (v) =>
                _requiredPositive(v, AppStrings.sellPriceRequiredPrompt),
          ),
          const SizedBox(height: 8),
          _tf(
            _costCup,
            AppStrings.cupCostLabel,
            numKeyboard,
            validator: (v) =>
                _requiredPositive(v, AppStrings.costPriceRequiredPrompt),
          ),
          if (_drinkSpicedEnabled) ...[
            const SizedBox(height: 8),
            _tf(
              _drinkSpicedPrice,
              AppStrings.spicedExtraPriceLabel,
              numKeyboard,
            ),
            const SizedBox(height: 8),
            _tf(_drinkSpicedCost, AppStrings.spicedExtraCostLabel, numKeyboard),
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

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now().toUtc();
      final name = _name.text.trim();
      final posOrder = _intOrNull(_posOrder.text);

      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }

      if (_t == NewItemType.drink) {
        final variants = _drinkVariants.map((e) => e.name).toList();
        final roasts = _drinkRoasts.map((e) => e.name).toList();
        final hasVariants = variants.isNotEmpty;

        final hasMatrix = variants.isNotEmpty || roasts.isNotEmpty;
        final pricing = <Map<String, dynamic>>[];
        double baseSell = _num(_sellCup.text);
        double baseCost = _num(_costCup.text);

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
              final variant = _drinkVariants.isEmpty
                  ? ''
                  : _variantNameFor(vId);
              final roast = _drinkRoasts.isEmpty ? '' : _roastNameFor(rId);

              final entry = <String, dynamic>{
                'sellPrice': _num(row.sellCtrl.text),
                'costPrice': _num(row.costCtrl.text),
              };
              if (variant.isNotEmpty) entry['variant'] = variant;
              if (roast.isNotEmpty) entry['roast'] = roast;
              if (_drinkSpicedEnabled) {
                entry['spicedPriceDelta'] = _num(row.spicedSellCtrl.text);
                entry['spicedCostDelta'] = _num(row.spicedCostCtrl.text);
              }
              pricing.add(entry);
            }
          }

          if (pricing.isNotEmpty) {
            baseSell = _num(pricing.first['sellPrice']);
            baseCost = _num(pricing.first['costPrice']);
          }
        }

        final hasRoastUsage = roasts.isNotEmpty;
        final roastUsage = <Map<String, dynamic>>[];
        if (hasRoastUsage) {
          _syncRoastUsage();
          final missingItem = _drinkRoasts.any(
            (roast) => _roastUsage[roast.id]?.item == null,
          );
          if (missingItem) {
            setState(() => _showRoastUsageErrors = true);
            return;
          } else if (_showRoastUsageErrors) {
            setState(() => _showRoastUsageErrors = false);
          }
          for (final roast in _drinkRoasts) {
            final usage = _roastUsage[roast.id]!;
            final item = usage.item!;
            final entry = <String, dynamic>{
              'roast': roast.name,
              'usedItem': {
                'id': item.id,
                'name': item.name,
                'variant': item.variant,
                'collection': usage.coll,
              },
            };
            if (hasVariants) {
              final usedAmounts = <String, double>{};
              for (final variant in _drinkVariants) {
                usedAmounts[variant.name] = _num(
                  usage.gramsFor(variant.id).text,
                );
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
        }

        final usedAmount = _num(_drinkUsedGrams.text);
        final usedItem = _drinkIngredient == null
            ? null
            : {
                'id': _drinkIngredient!.id,
                'name': _drinkIngredient!.name,
                'variant': _drinkIngredient!.variant,
                'collection': _drinkIngredientColl,
              };

        final payload = <String, dynamic>{
          'name': name,
          'unit': 'cup',
          'sellPrice': baseSell,
          'costPrice': baseCost,
          'image': 'assets/drinks.jpg',
          'variants': variants,
          'roastLevels': roasts,
          'spicedEnabled': _drinkSpicedEnabled,
          'createdAt': now,
        };
        if (posOrder != null) {
          payload['posOrder'] = posOrder;
          payload['pos_order'] = posOrder;
        }

        if (!hasMatrix && _drinkSpicedEnabled) {
          payload['spicedPriceDelta'] = _num(_drinkSpicedPrice.text);
          payload['spicedCostDelta'] = _num(_drinkSpicedCost.text);
        }
        if (pricing.isNotEmpty) {
          payload['pricing'] = pricing;
        }
        if (hasRoastUsage && roastUsage.isNotEmpty) {
          payload['roastUsage'] = roastUsage;
        } else {
          if (usedItem != null) {
            payload['usedItem'] = usedItem;
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
              payload['usedAmountByVariant'] = usedByVariant;
              payload['usedAmount'] = usedByVariant.values.first;
            }
          } else if (usedAmount > 0) {
            payload['usedAmount'] = usedAmount;
          }
        }

        await db.collection('drinks').add(payload);
      } else if (_t == NewItemType.extra) {
        final category = _category.text.trim();
        await db.collection('extras').add({
          'name': name,
          'category': category,
          'unit': _extraUnit.text.trim().isEmpty
              ? 'piece'
              : _extraUnit.text.trim(),
          'stock_units': _num(_stock.text),
          'price_sell': _num(_extraPrice.text),
          'cost_unit': _num(_extraCost.text),
          'active': _extraActive,
          'type': 'extra',
          'is_extra': true,
          'created_at': now,
          'updated_at': now,
          if (posOrder != null) 'posOrder': posOrder,
          if (posOrder != null) 'pos_order': posOrder,
        });
      } else {
        final col = _t == NewItemType.single ? 'singles' : 'blends';
        final spicePrice = _itemSpicedEnabled
            ? _num(_spicePricePerKg.text)
            : 0.0;
        final spiceCost = _itemSpicedEnabled ? _num(_spiceCostPerKg.text) : 0.0;
        final ginsengPrice = _itemGinsengEnabled
            ? _num(_ginsengPricePerKg.text)
            : 0.0;
        final ginsengCost = _itemGinsengEnabled
            ? _num(_ginsengCostPerKg.text)
            : 0.0;

        if (_itemRoasts.isEmpty) {
          final baseSell = _num(_baseSellPerKg.text);
          final baseCost = _num(_baseCostPerKg.text);

          final payload = <String, dynamic>{
            'name': name,
            'variant': '',
            'unit': 'g',
            'stock': _num(_stock.text),
            'minLevel': 0,
            'sellPricePerKg': baseSell,
            'costPricePerKg': baseCost,
            'spicedEnabled': _itemSpicedEnabled,
            'spicePricePerKg': spicePrice,
            'spiceCostPerKg': spiceCost,
            'spicesPrice': spicePrice,
            'spicesCost': spiceCost,
            if (_itemGinsengEnabled) 'ginsengEnabled': true,
            if (_itemGinsengEnabled) 'ginsengPricePerKg': ginsengPrice,
            if (_itemGinsengEnabled) 'ginsengCostPerKg': ginsengCost,
            'image': col == 'singles'
                ? 'assets/singles.jpg'
                : 'assets/blends.jpg',
            'createdAt': now,
            if (posOrder != null) 'posOrder': posOrder,
            if (posOrder != null) 'pos_order': posOrder,
          };
          final docRef = await db.collection(col).add(payload);
          await _logInventoryCreate(
            collection: col,
            id: docRef.id,
            name: name,
            variant: '',
            stock: _num(_stock.text),
            sellPerKg: baseSell,
            costPerKg: baseCost,
          );
        } else {
          final batch = db.batch();
          final logEntries = <Map<String, dynamic>>[];
          for (final entry in _itemRoasts) {
            final docRef = db.collection(col).doc();
            final payload = <String, dynamic>{
              'name': name,
              'variant': entry.name,
              'unit': 'g',
              'stock': _num(entry.stockCtrl.text),
              'minLevel': 0,
              'sellPricePerKg': _num(entry.sellCtrl.text),
              'costPricePerKg': _num(entry.costCtrl.text),
              'spicedEnabled': _itemSpicedEnabled,
              'spicePricePerKg': spicePrice,
              'spiceCostPerKg': spiceCost,
              'spicesPrice': spicePrice,
              'spicesCost': spiceCost,
              if (_itemGinsengEnabled) 'ginsengEnabled': true,
              if (_itemGinsengEnabled) 'ginsengPricePerKg': ginsengPrice,
              if (_itemGinsengEnabled) 'ginsengCostPerKg': ginsengCost,
              'image': col == 'singles'
                  ? 'assets/singles.jpg'
                  : 'assets/blends.jpg',
              'createdAt': now,
              if (posOrder != null) 'posOrder': posOrder,
              if (posOrder != null) 'pos_order': posOrder,
            };
            batch.set(docRef, payload);
            logEntries.add({
              'id': docRef.id,
              'variant': entry.name,
              'stock': _num(entry.stockCtrl.text),
              'sell': _num(entry.sellCtrl.text),
              'cost': _num(entry.costCtrl.text),
            });
          }
          await batch.commit();
          for (final entry in logEntries) {
            await _logInventoryCreate(
              collection: col,
              id: entry['id'] as String,
              name: name,
              variant: (entry['variant'] ?? '').toString(),
              stock: _num(entry['stock']),
              sellPerKg: _num(entry['sell']),
              costPerKg: _num(entry['cost']),
            );
          }
        }
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

  Future<void> _logInventoryCreate({
    required String collection,
    required String id,
    required String name,
    required String variant,
    required double stock,
    required double sellPerKg,
    required double costPerKg,
  }) async {
    try {
      await logInventoryChange(
        action: 'create',
        collection: collection,
        itemId: id,
        name: name,
        variant: variant,
        before: const <String, dynamic>{},
        after: {
          'stock': stock,
          'sell_per_kg': sellPerKg,
          'cost_per_kg': costPerKg,
        },
        unit: 'g',
        source: 'manage_create',
      );
    } catch (_) {
      // ignore log failures
    }
  }

  int? _intOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  String? _requiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _requiredPositive(String? value, String message) {
    if (_num(value) <= 0) return message;
    return null;
  }

  String? _optionalInt(String? value, String message) {
    if (value == null || value.trim().isEmpty) return null;
    return _intOrNull(value) == null ? message : null;
  }
}
