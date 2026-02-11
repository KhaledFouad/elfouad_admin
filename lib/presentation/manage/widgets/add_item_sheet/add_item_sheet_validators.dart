part of '../add_item_sheet.dart';

/// Parsing and validation helpers for add-item payload creation.
extension _AddItemSheetValidators on _AddItemSheetState {
  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  List<String> _normalizedSelectedExtraIds() {
    final ids =
        _itemSelectedExtraIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ids;
  }

  List<Map<String, dynamic>> _selectedExtrasPayload(List<String> ids) {
    if (ids.isEmpty) return const <Map<String, dynamic>>[];
    final options = context.read<TahwigaCubit>().state.items;
    final byId = {for (final extra in options) extra.id: extra};
    return ids.map((id) {
      final extra = byId[id];
      if (extra == null) {
        return <String, dynamic>{'id': id};
      }
      return <String, dynamic>{
        'id': extra.id,
        'name': extra.name,
        'category': extra.category,
        'unit': extra.unit,
      };
    }).toList();
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
