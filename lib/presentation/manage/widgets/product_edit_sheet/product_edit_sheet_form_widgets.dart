// ignore_for_file: invalid_use_of_protected_member
part of '../product_edit_sheet.dart';

/// Form sections and pickers used by the edit sheet UI.
extension _ProductEditSheetFormWidgets on _ProductEditSheetState {
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

  Widget _buildBeanExtrasPicker({
    required List<ExtraRow> extras,
    required bool loading,
  }) {
    final options =
        extras
            .where((e) => e.active || _beanSelectedExtraIds.contains(e.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (loading && options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          AppStrings.additionsEmptyHint,
          style: TextStyle(color: Colors.brown.shade400),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          AppStrings.additionsPickerTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.additionsSelectedCount(_beanSelectedExtraIds.length),
          style: TextStyle(
            color: Colors.brown.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((extra) {
            final selected = _beanSelectedExtraIds.contains(extra.id);
            return FilterChip(
              selected: selected,
              label: Text(extra.name),
              onSelected: (picked) {
                setState(() {
                  if (picked) {
                    _beanSelectedExtraIds.add(extra.id);
                  } else {
                    _beanSelectedExtraIds.remove(extra.id);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
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
}
