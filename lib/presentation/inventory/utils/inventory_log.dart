import 'package:cloud_firestore/cloud_firestore.dart';

const String inventoryLogsCollection = 'inventory_logs';

Future<void> logInventoryChange({
  required String action,
  required String collection,
  required String itemId,
  required String name,
  String variant = '',
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
  String unit = 'g',
  String? source,
}) async {
  final normalized = _normalizeBeforeAfter(
    action: action,
    before: before,
    after: after,
  );
  if (normalized.skip) return;

  final data = <String, dynamic>{
    'action': action,
    'collection': collection,
    'item_id': itemId,
    'name': name,
    'variant': variant,
    'unit': unit,
    'changed_at': FieldValue.serverTimestamp(),
  };
  if (normalized.before != null) data['before'] = normalized.before;
  if (normalized.after != null) data['after'] = normalized.after;
  if (source != null && source.trim().isNotEmpty) {
    data['source'] = source.trim();
  }

  await FirebaseFirestore.instance
      .collection(inventoryLogsCollection)
      .add(data);
}

_NormalizedBeforeAfter _normalizeBeforeAfter({
  required String action,
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
}) {
  final beforeMap = _cleanMap(before);
  final afterMap = _cleanMap(after);

  if (action != 'update') {
    return _NormalizedBeforeAfter(
      before: beforeMap.isEmpty ? null : beforeMap,
      after: afterMap.isEmpty ? null : afterMap,
      skip: false,
    );
  }

  final keys = <String>{...beforeMap.keys, ...afterMap.keys};
  if (keys.isEmpty) {
    return const _NormalizedBeforeAfter(skip: true);
  }

  final changedBefore = <String, dynamic>{};
  final changedAfter = <String, dynamic>{};

  for (final key in keys) {
    final hasBefore = beforeMap.containsKey(key);
    final hasAfter = afterMap.containsKey(key);
    if (!hasBefore && !hasAfter) continue;

    final beforeValue = beforeMap[key];
    final afterValue = afterMap[key];
    if (_valuesEqual(beforeValue, afterValue)) continue;

    if (hasBefore) changedBefore[key] = beforeValue;
    if (hasAfter) changedAfter[key] = afterValue;
  }

  if (changedBefore.isEmpty && changedAfter.isEmpty) {
    return const _NormalizedBeforeAfter(skip: true);
  }

  return _NormalizedBeforeAfter(
    before: changedBefore.isEmpty ? null : changedBefore,
    after: changedAfter.isEmpty ? null : changedAfter,
    skip: false,
  );
}

Map<String, dynamic> _cleanMap(Map<String, dynamic>? value) {
  if (value == null) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

bool _valuesEqual(dynamic a, dynamic b) {
  final an = _asNumber(a);
  final bn = _asNumber(b);
  if (an != null && bn != null) {
    return (an - bn).abs() <= 0.0001;
  }

  if (a is String || b is String) {
    final sa = (a ?? '').toString().trim();
    final sb = (b ?? '').toString().trim();
    return sa == sb;
  }

  if (a is bool || b is bool) {
    return a == b;
  }

  return a == b;
}

double? _asNumber(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.').trim());
  }
  return null;
}

class _NormalizedBeforeAfter {
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final bool skip;

  const _NormalizedBeforeAfter({this.before, this.after, this.skip = false});
}
