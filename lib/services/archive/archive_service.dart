// ignore_for_file: unnecessary_cast

import 'package:cloud_firestore/cloud_firestore.dart';

const String archiveBinCollection = 'archive_bin';
const String _defaultArchivedBy = 'device';

Map<String, dynamic> buildArchiveEntry({
  required DocumentReference<Map<String, dynamic>> srcRef,
  required String kind,
  required Map<String, dynamic> data,
  String? reason,
  String? archivedBy,
}) {
  final trimmedReason = reason?.trim();
  final trimmedBy = archivedBy?.trim();
  final entry = <String, dynamic>{
    'kind': kind,
    'original_path': srcRef.path,
    'original_collection': srcRef.parent.id,
    'original_id': srcRef.id,
    'archived_at': FieldValue.serverTimestamp(),
    'archived_by': (trimmedBy == null || trimmedBy.isEmpty)
        ? _defaultArchivedBy
        : trimmedBy,
    if (trimmedReason != null && trimmedReason.isNotEmpty)
      'reason': trimmedReason,
    'data': data,
  };

  final display = _extractDisplayFields(kind, data);
  entry.addAll(display);
  return entry;
}

Future<void> archiveThenDelete({
  required DocumentReference<Map<String, dynamic>> srcRef,
  required String kind,
  String? reason,
  String? archivedBy,
}) async {
  final snap = await srcRef.get();
  if (!snap.exists) return;
  final data = snap.data();
  if (data == null) return;

  final archiveData = buildArchiveEntry(
    srcRef: srcRef,
    kind: kind,
    data: data,
    reason: reason,
    archivedBy: archivedBy,
  );

  final archiveRef = srcRef.firestore.collection(archiveBinCollection).doc();
  final batch = srcRef.firestore.batch();
  batch.set(archiveRef, archiveData);
  batch.delete(srcRef);
  await batch.commit();
}

Future<void> restoreFromArchive({
  required DocumentReference<Map<String, dynamic>> archiveRef,
  bool removeFromArchive = true,
}) async {
  final snap = await archiveRef.get();
  if (!snap.exists) return;
  final data = snap.data();
  if (data == null) return;

  final originalPath = data['original_path'];
  final payload = data['data'];
  if (originalPath is! String || originalPath.isEmpty) return;
  if (payload is! Map) return;

  final originalRef = archiveRef.firestore.doc(originalPath);

  final batch = archiveRef.firestore.batch();
  batch.set(originalRef, payload.cast<String, dynamic>());
  if (removeFromArchive) {
    batch.delete(archiveRef);
  }
  await batch.commit();
}

Map<String, dynamic> _extractDisplayFields(
  String kind,
  Map<String, dynamic> data,
) {
  final out = <String, dynamic>{};

  String? displayName;
  switch (kind) {
    case 'sale':
      final invoice = data['invoice_number'];
      if (invoice != null) {
        displayName = 'Invoice #$invoice';
      }
      break;
    case 'expense':
      displayName = (data['title'] ?? '').toString();
      break;
    case 'recipe':
      displayName = (data['name'] ?? '').toString();
      break;
    case 'drink':
    case 'extra':
    case 'product_single':
    case 'blend':
    case 'inventory_row':
      final name = (data['name'] ?? '').toString();
      final variant = (data['variant'] ?? '').toString();
      if (name.isNotEmpty && variant.isNotEmpty) {
        displayName = '$name - $variant';
      } else {
        displayName = name;
      }
      break;
  }

  if (displayName != null && displayName.trim().isNotEmpty) {
    out['display_name'] = displayName.trim();
  }

  if (data.containsKey('created_at')) {
    out['created_at_original'] = data['created_at'];
  } else if (data.containsKey('createdAt')) {
    out['created_at_original'] = data['createdAt'];
  }

  if (data.containsKey('total_price')) {
    out['total_price'] = data['total_price'];
  }

  return out;
}
