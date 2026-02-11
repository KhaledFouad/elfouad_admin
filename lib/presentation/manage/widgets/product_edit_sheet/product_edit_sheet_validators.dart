part of '../product_edit_sheet.dart';

/// Primitive parsing and validators used across form fields.
extension _ProductEditSheetValidators on _ProductEditSheetState {
  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  int? _intOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  String _format(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
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

  void _applyPosOrder(Map<String, dynamic> upd) {
    final text = _posOrder.text.trim();
    if (text.isEmpty) {
      upd['posOrder'] = FieldValue.delete();
      upd['pos_order'] = FieldValue.delete();
      return;
    }
    final posOrder = _intOrNull(text);
    if (posOrder != null) {
      upd['posOrder'] = posOrder;
      upd['pos_order'] = posOrder;
    }
  }
}
