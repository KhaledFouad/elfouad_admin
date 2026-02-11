part of '../product_edit_sheet.dart';

/// Stateful host that composes extracted form sections.
class _ProductEditSheetState extends State<ProductEditSheet> {
  static const _defaultVariantId = '_default_variant';
  static const _defaultRoastId = '_default_roast';

  late Map<String, dynamic> _data;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _posOrder = TextEditingController();
  final _variant = TextEditingController();
  final _unit = TextEditingController();
  final _stock = TextEditingController();

  final _sellPerKg = TextEditingController();
  final _costPerKg = TextEditingController();
  final _spicePricePerKg = TextEditingController();
  final _spiceCostPerKg = TextEditingController();
  bool _beanSpicedEnabled = false;
  bool _beanExtrasEnabled = false;
  final Set<String> _beanSelectedExtraIds = <String>{};

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
    final posRaw = _data['posOrder'] ?? _data['pos_order'];
    if (posRaw != null) {
      _posOrder.text = _format(_num(posRaw));
    }
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

  @override
  void dispose() {
    _name.dispose();
    _posOrder.dispose();
    _variant.dispose();
    _unit.dispose();
    _stock.dispose();
    _sellPerKg.dispose();
    _costPerKg.dispose();
    _spicePricePerKg.dispose();
    _spiceCostPerKg.dispose();
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

  @override
  Widget build(BuildContext context) {
    final tahwigaState = context.watch<TahwigaCubit>().state;
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
            const SizedBox(height: 8),
            _tf(
              _posOrder,
              AppStrings.posOrderLabel,
              const TextInputType.numberWithOptions(decimal: false),
              validator: (v) =>
                  _optionalInt(v, AppStrings.posOrderInvalidPrompt),
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
                  value: _beanExtrasEnabled,
                  onChanged: (v) =>
                      setState(() => _beanExtrasEnabled = v ?? false),
                  title: const Text(AppStrings.additionsOptionLabel),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              if (_beanExtrasEnabled)
                _buildBeanExtrasPicker(
                  extras: tahwigaState.items,
                  loading: tahwigaState.loading,
                ),
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
}
