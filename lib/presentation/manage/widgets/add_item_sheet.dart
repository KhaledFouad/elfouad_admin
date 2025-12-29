import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';
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
  _DrinkPriceEntry({
    required this.variantId,
    required this.roastId,
  })  : sellCtrl = TextEditingController(text: '0.0'),
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
  final _drinkSpicedPrice = TextEditingController(text: '0.0');
  final _drinkSpicedCost = TextEditingController(text: '0.0');
  final _extraPrice = TextEditingController(text: '0.0');
  final _extraCost = TextEditingController(text: '0.0');
  bool _extraActive = true;
  final List<_OptionEntry> _drinkVariants = [];
  final List<_OptionEntry> _drinkRoasts = [];
  final Map<String, _DrinkPriceEntry> _drinkPrices = {};
  final _drinkUsedGrams = TextEditingController();
  InventoryRow? _drinkIngredient;
  String? _drinkIngredientColl;
  bool _drinkSpicedEnabled = false;
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
    _variant.dispose();
    _stock.dispose();
    _sellPerKg.dispose();
    _costPerKg.dispose();
    _sellCup.dispose();
    _costCup.dispose();
    _drinkSpicedPrice.dispose();
    _drinkSpicedCost.dispose();
    _category.dispose();
    _extraUnit.dispose();
    _extraPrice.dispose();
    _extraCost.dispose();
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
            ] else if (_t != NewItemType.drink) ...[
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

  String _nextOptionId() => 'opt_${_optionSeq++}';

  String _priceKey(String variantId, String roastId) =>
      '$variantId::$roastId';

  void _clearDrinkPrices() {
    for (final entry in _drinkPrices.values) {
      entry.dispose();
    }
    _drinkPrices.clear();
  }

  void _syncDrinkPricing() {
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

    final removeKeys =
        _drinkPrices.keys.where((k) => !wantedKeys.contains(k)).toList();
    for (final key in removeKeys) {
      _drinkPrices[key]?.dispose();
      _drinkPrices.remove(key);
    }
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
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
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
          _tf(_sellCup, AppStrings.cupPriceLabel, numKeyboard),
          const SizedBox(height: 8),
          _tf(_costCup, AppStrings.cupCostLabel, numKeyboard),
          if (_drinkSpicedEnabled) ...[
            const SizedBox(height: 8),
            _tf(_drinkSpicedPrice, AppStrings.spicedExtraPriceLabel, numKeyboard),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _tf(
                          row.costCtrl,
                          AppStrings.costLabelDefinite,
                          numKeyboard,
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
        _tf(
          _drinkUsedGrams,
          AppStrings.usedGramsLabel,
          const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Future<void> _pickDrinkIngredient({
    required String coll,
    required List<InventoryRow> source,
    required bool loading,
  }) async {
    final chosen = await showDialog<InventoryRow>(
      context: context,
      builder: (_) {
        final search = TextEditingController();
        return AlertDialog(
          title: Text(
            coll == 'singles' ? AppStrings.pickSingleItem : AppStrings.pickBlend,
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
                                    final t =
                                        '${r.name} ${r.variant}'.toLowerCase();
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
                                        AppStrings.pricePerKgInline(r.sellPerKg),
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

      if (_t == NewItemType.drink) {
        final name = _name.text.trim();
        final variants = _drinkVariants.map((e) => e.name).toList();
        final roasts = _drinkRoasts.map((e) => e.name).toList();

        if (variants.any((n) => n.isEmpty)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.fillVariantNamesPrompt)),
            );
          }
          return;
        }
        if (roasts.any((n) => n.isEmpty)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.fillRoastNamesPrompt)),
            );
          }
          return;
        }

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
              final variant = _drinkVariants.isEmpty ? '' : _variantNameFor(vId);
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

        if (!hasMatrix && _drinkSpicedEnabled) {
          payload['spicedPriceDelta'] = _num(_drinkSpicedPrice.text);
          payload['spicedCostDelta'] = _num(_drinkSpicedCost.text);
        }
        if (pricing.isNotEmpty) {
          payload['pricing'] = pricing;
        }
        if (usedItem != null) {
          payload['usedItem'] = usedItem;
        }
        if (usedAmount > 0) {
          payload['usedAmount'] = usedAmount;
        }

        await db.collection('drinks').add(payload);
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


