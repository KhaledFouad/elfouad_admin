part of '../product_edit_sheet.dart';

/// Mapping helpers for lists, maps, and extras payload derivation.
extension _ProductEditSheetMapperHelpers on _ProductEditSheetState {
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

  List<String> _extractExtraOptionIds(Map<String, dynamic> data) {
    final ids = <String>{};
    final rawIds = data['extraOptionIds'];
    if (rawIds is Iterable) {
      for (final entry in rawIds) {
        final id = entry?.toString().trim() ?? '';
        if (id.isNotEmpty) ids.add(id);
      }
    }
    final rawOptions = data['extraOptions'];
    if (rawOptions is Iterable) {
      for (final entry in rawOptions) {
        if (entry is! Map) continue;
        final id = (entry['id'] ?? '').toString().trim();
        if (id.isNotEmpty) ids.add(id);
      }
    }
    final list = ids.toList()..sort();
    return list;
  }

  List<String> _normalizedBeanExtraIds() {
    final ids =
        _beanSelectedExtraIds
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
    final legacyById = <String, Map<String, dynamic>>{};
    for (final option in _mapList(_data['extraOptions'])) {
      final id = (option['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      legacyById[id] = option;
    }

    return ids.map((id) {
      final extra = byId[id];
      if (extra != null) {
        return <String, dynamic>{
          'id': extra.id,
          'name': extra.name,
          'category': extra.category,
          'unit': extra.unit,
        };
      }
      final legacy = legacyById[id];
      if (legacy != null) {
        return <String, dynamic>{
          'id': id,
          'name': (legacy['name'] ?? '').toString(),
          'category': (legacy['category'] ?? '').toString(),
          'unit': (legacy['unit'] ?? '').toString(),
        };
      }
      return <String, dynamic>{'id': id};
    }).toList();
  }
}
