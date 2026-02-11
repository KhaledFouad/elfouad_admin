// ignore_for_file: invalid_use_of_protected_member
part of '../add_item_sheet.dart';

/// Shared form widgets used by non-drink and common sections.
extension _AddItemSheetFormCommon on _AddItemSheetState {
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

  Widget _buildBeanExtrasPicker({
    required List<ExtraRow> extras,
    required bool loading,
  }) {
    final options = _activeExtras(extras);
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
          AppStrings.additionsSelectedCount(_itemSelectedExtraIds.length),
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
            final selected = _itemSelectedExtraIds.contains(extra.id);
            return FilterChip(
              selected: selected,
              label: Text(extra.name),
              onSelected: (picked) {
                setState(() {
                  if (picked) {
                    _itemSelectedExtraIds.add(extra.id);
                  } else {
                    _itemSelectedExtraIds.remove(extra.id);
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

  List<ExtraRow> _activeExtras(List<ExtraRow> extras) {
    return extras
        .where((e) => e.active || _itemSelectedExtraIds.contains(e.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
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
}
