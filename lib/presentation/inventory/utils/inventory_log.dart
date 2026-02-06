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
  final data = <String, dynamic>{
    'action': action,
    'collection': collection,
    'item_id': itemId,
    'name': name,
    'variant': variant,
    'unit': unit,
    'changed_at': FieldValue.serverTimestamp(),
  };
  if (before != null) data['before'] = before;
  if (after != null) data['after'] = after;
  if (source != null && source.trim().isNotEmpty) {
    data['source'] = source.trim();
  }

  await FirebaseFirestore.instance
      .collection(inventoryLogsCollection)
      .add(data);
}
