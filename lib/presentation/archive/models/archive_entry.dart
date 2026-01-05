import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/History/utils/sale_utils.dart';

class ArchiveEntry {
  ArchiveEntry({
    required this.ref,
    required this.id,
    required this.kind,
    required this.originalPath,
    required this.originalCollection,
    required this.originalId,
    required this.archivedAt,
    required this.archivedBy,
    required this.reason,
    required this.data,
    required this.displayName,
    required this.createdAtOriginal,
    required this.totalPrice,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String id;
  final String kind;
  final String originalPath;
  final String originalCollection;
  final String originalId;
  final DateTime archivedAt;
  final String archivedBy;
  final String? reason;
  final Map<String, dynamic> data;
  final String? displayName;
  final DateTime? createdAtOriginal;
  final double? totalPrice;

  factory ArchiveEntry.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final archivedAtRaw = data['archived_at'];
    final archivedAt = parseDate(archivedAtRaw);
    final createdAtRaw = data['created_at_original'];
    final createdAtOriginal = createdAtRaw == null
        ? null
        : parseDate(createdAtRaw);

    return ArchiveEntry(
      ref: doc.reference,
      id: doc.id,
      kind: (data['kind'] ?? '').toString(),
      originalPath: (data['original_path'] ?? '').toString(),
      originalCollection: (data['original_collection'] ?? '').toString(),
      originalId: (data['original_id'] ?? '').toString(),
      archivedAt: archivedAt,
      archivedBy: (data['archived_by'] ?? '').toString(),
      reason: (data['reason'] ?? '').toString().isEmpty
          ? null
          : (data['reason'] ?? '').toString(),
      data: (data['data'] is Map)
          ? (data['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{},
      displayName: (data['display_name'] ?? '').toString().isEmpty
          ? null
          : (data['display_name'] ?? '').toString(),
      createdAtOriginal: createdAtOriginal,
      totalPrice: _parseDouble(data['total_price']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
