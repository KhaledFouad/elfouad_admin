part of '../add_item_sheet.dart';

/// Stateful host that composes extracted add-item sections.
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
  bool _itemSpicedEnabled = false;
  bool _itemExtrasEnabled = false;
  final Set<String> _itemSelectedExtraIds = <String>{};
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
    final tahwigaState = context.watch<TahwigaCubit>().state;
    final categoryText = _category.text.trim().toLowerCase();
    final categoryExists =
        (_t == NewItemType.extra || _t == NewItemType.tahwiga) &&
        categoryText.isNotEmpty &&
        (_t == NewItemType.tahwiga ? tahwigaState.items : extrasState.items)
            .any((e) => e.category.trim().toLowerCase() == categoryText);

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
                    label: Text(AppStrings.extrasLabel),
                  ),
                  ButtonSegment(
                    value: NewItemType.tahwiga,
                    label: Text(AppStrings.tahwigaLabel),
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
              if (_t == NewItemType.extra || _t == NewItemType.tahwiga) ...[
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
                if (_t == NewItemType.extra) ...[
                  _tf(
                    _stock,
                    AppStrings.stockUnitsLabel,
                    const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                ],
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
                    value: _itemExtrasEnabled,
                    onChanged: (v) =>
                        setState(() => _itemExtrasEnabled = v ?? false),
                    title: const Text(AppStrings.additionsOptionLabel),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                if (_itemExtrasEnabled)
                  _buildBeanExtrasPicker(
                    extras: tahwigaState.items,
                    loading: tahwigaState.loading,
                  ),
              ],
              if (_t != NewItemType.extra && _t != NewItemType.tahwiga)
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
      ),
    );
  }
}
