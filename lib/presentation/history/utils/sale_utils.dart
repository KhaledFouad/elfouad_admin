import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:flutter/material.dart';
import '../models/sale_component.dart';

const _deferredReferenceHour = 5;
const _dayBoundaryHour = 4;

DateTimeRange defaultSalesRange() {
  final now = DateTime.now();
  final today4am = DateTime(now.year, now.month, now.day, _dayBoundaryHour);
  if (now.isBefore(today4am)) {
    final start = today4am.subtract(const Duration(days: 1));
    return DateTimeRange(start: start, end: today4am);
  }
  final end = today4am.add(const Duration(days: 1));
  return DateTimeRange(start: today4am, end: end);
}

double parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '0') ?? 0;
}

int? parseOptionalInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  final str = value?.toString();
  return DateTime.tryParse(str ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
}

DateTime? parseOptionalDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

DateTime computeEffectiveTime({
  required DateTime createdAt,
  required DateTime? settledAt,
  required bool isDeferred,
  required bool isPaid,
}) {
  if (isDeferred && !isPaid) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, _deferredReferenceHour);
  }
  if (isPaid && settledAt != null) {
    return settledAt;
  }
  return createdAt;
}

bool isSameMinute(DateTime a, DateTime b) {
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;
}

String formatTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String formatDateTime(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d  $h:$min';
}

String detectSaleType(Map<String, dynamic> data) {
  final rawType = (data['type'] ?? '').toString();
  if (rawType.isNotEmpty) {
    if (rawType == 'extra') return 'extra';
    return rawType;
  }
  if (data.containsKey('components')) return 'custom_blend';
  if (data.containsKey('drink_id') || data.containsKey('drink_name')) {
    return 'drink';
  }
  if (data.containsKey('single_id') || data.containsKey('single_name')) {
    return 'single';
  }
  if (data.containsKey('blend_id') || data.containsKey('blend_name')) {
    return 'ready_blend';
  }
  if (data.containsKey('extra_id') || data.containsKey('extra_name')) {
    return 'extra';
  }
  final items = _asListMap(data['items']);
  if (items.isNotEmpty) {
    final hasGrams = items.any((element) => element.containsKey('grams'));
    if (hasGrams) return 'single';
  }
  return 'unknown';
}

List<SaleComponent> extractComponents(Map<String, dynamic> data, String type) {
  // 1) لو في components جاهزة (مثلاً custom_blend القديمة)
  final components = _asListMap(data['components']);
  if (components.isNotEmpty) {
    return components.map(SaleComponent.fromMap).toList();
  }

  // 2) لو في items (فاتورة POS)
  final items = _asListMap(data['items']);
  if (items.isNotEmpty) {
    // فاتورة من الـ POS
    if (type == 'invoice') {
      final List<SaleComponent> result = [];

      for (final item in items) {
        // البند الأساسي زي ما هو
        var base = SaleComponent.fromMap(item);

        final itemType = (item['type'] ?? '').toString();

        // لو البند ده "خلطة مخصصة" وفيه meta.components نخلي الاسم يحتوي على التفاصيل
        if (itemType == 'custom_blend') {
          final meta = item['meta'];
          final metaComponents = meta is Map<String, dynamic>
              ? _asListMap(meta['components'])
              : const <Map<String, dynamic>>[];

          if (metaComponents.isNotEmpty) {
            final detailParts = <String>[];

            for (final c in metaComponents) {
              final name = (c['name'] ?? '').toString();
              final variant = (c['variant'] ?? '').toString();
              final grams = parseDouble(c['grams'] ?? c['weight']);

              if (name.isEmpty) continue;

              String label = name;
              if (variant.isNotEmpty) {
                label = '$name - $variant';
              }
              if (grams > 0) {
                label = '$label ${grams.toStringAsFixed(0)} جم';
              }

              detailParts.add(label);
            }

            if (detailParts.isNotEmpty) {
              final baseName = base.name.isNotEmpty ? base.name : 'خلطة مخصصة';
              // مثال: "خلطة مخصصة (اندونيسي فاتح 100 جم + برازيلي غامق 50 جم)"
              final newName = '$baseName (${detailParts.join(' + ')})';
              base = base.copyWith(name: newName);
            }
          }
        }

        result.add(base);
      }

      return result;
    }

    // أي نوع تاني (مثلاً single قديمة) نرجعه زي ما هو
    return items.map(SaleComponent.fromMap).toList();
  }

  // 3) بعض الأنواع القديمة تستخدم lines
  final lines = _asListMap(data['lines']);
  if (lines.isNotEmpty) {
    return lines.map(SaleComponent.fromMap).toList();
  }

  // 4) الأنواع المنفردة
  if (type == 'drink') {
    final name = (data['drink_name'] ?? data['name'] ?? AppStrings.labelDrink)
        .toString();
    final variant = (data['roast'] ?? data['variant'] ?? '').toString();
    final quantity = parseDouble(data['quantity'] ?? data['qty'] ?? 1);
    final unit = (data['unit'] ?? 'cup').toString();
    final unitPrice = parseDouble(data['unit_price']);
    final unitCost = parseDouble(data['unit_cost']);
    final totalPrice = parseDouble(data['total_price']);
    final totalCost = parseDouble(data['total_cost']);
    final map = <String, dynamic>{
      'name': name,
      'variant': variant,
      'qty': quantity,
      'unit': unit,
      'total_price': totalPrice > 0 ? totalPrice : unitPrice * quantity,
      'total_cost': totalCost > 0 ? totalCost : unitCost * quantity,
      'meta': data['meta'],
    };
    return [SaleComponent.fromMap(map)];
  }

  if (type == 'single' || type == 'ready_blend') {
    final name = (data['name'] ?? '').toString();
    final variant = (data['variant'] ?? '').toString();
    final grams = parseDouble(data['grams']);
    final totalPrice = parseDouble(data['total_price']);
    final totalCost = parseDouble(data['total_cost']);
    final map = <String, dynamic>{
      'name': name,
      'variant': variant,
      'grams': grams,
      'unit': 'g',
      'total_price': totalPrice,
      'total_cost': totalCost,
      'meta': data['meta'],
    };
    return [SaleComponent.fromMap(map)];
  }

  if (type == 'extra') {
    final name = (data['extra_name'] ?? data['name'] ?? AppStrings.labelExtra)
        .toString();
    final variant = (data['variant'] ?? '').toString();
    final quantity = parseDouble(data['quantity'] ?? data['qty'] ?? 1);
    final unit = (data['unit'] ?? 'piece').toString();
    final unitPrice = parseDouble(data['unit_price']);
    final unitCost = parseDouble(data['unit_cost']);
    final totalPrice = parseDouble(data['total_price']);
    final totalCost = parseDouble(data['total_cost']);
    final map = <String, dynamic>{
      'name': name,
      'variant': variant,
      'qty': quantity,
      'unit': unit,
      'total_price': totalPrice > 0 ? totalPrice : unitPrice * quantity,
      'total_cost': totalCost > 0 ? totalCost : unitCost * quantity,
      'meta': data['meta'],
    };
    return [SaleComponent.fromMap(map)];
  }

  return const [];
}

String normalizeUnit(String unit) {
  if (unit.trim().toLowerCase() == 'piece') {
    return AppStrings.labelPieceUnit;
  }
  return unit;
}

String buildTitleLine(Map<String, dynamic> data, String type) {
  String name = (data['name'] ?? '').toString();
  String variant = (data['variant'] ?? data['roast'] ?? '').toString();
  String labelNV = variant.isNotEmpty ? '$name $variant' : name;

  switch (type) {
    case 'drink':
      final quantity = parseDouble(data['quantity']).toStringAsFixed(0);
      final drinkName = (data['drink_name'] ?? '').toString();
      final finalName = labelNV.isNotEmpty
          ? labelNV
          : (drinkName.isNotEmpty ? drinkName : AppStrings.labelDrink);
      return AppStrings.saleTitleDrink(quantity, finalName);
    case 'invoice':
      final invoiceNumber = parseOptionalInt(data['invoice_number']);
      if (invoiceNumber != null && invoiceNumber > 0) {
        return AppStrings.saleTitleInvoiceNumber(invoiceNumber);
      }
      final items = _asListMap(data['items']);
      final count = items.length;
      final amount = parseDouble(data['total_price']).toStringAsFixed(2);
      return AppStrings.saleTitleInvoice(count, amount);
    case 'single':
      final grams = parseDouble(data['grams']).toStringAsFixed(0);
      final lbl = labelNV.isNotEmpty ? labelNV : name;
      return AppStrings.saleTitleSingle(grams, lbl);
    case 'ready_blend':
      final grams = parseDouble(data['grams']).toStringAsFixed(0);
      final lbl = labelNV.isNotEmpty ? labelNV : name;
      return AppStrings.saleTitleReadyBlend(grams, lbl);
    case 'custom_blend':
      return AppStrings.saleTitleCustomBlend();
    case 'extra':
      final quantity = parseDouble(
        data['quantity'] ?? data['qty'] ?? 1,
      ).toStringAsFixed(0);
      final extraName =
          (data['extra_name'] ?? data['name'] ?? AppStrings.labelExtra)
              .toString();
      final unit = normalizeUnit((data['unit'] ?? 'piece').toString());
      return AppStrings.saleTitleExtra(quantity, unit, extraName);
    default:
      return AppStrings.labelOperation;
  }
}

List<Map<String, dynamic>> _asListMap(dynamic value) {
  if (value is List) {
    return value
        .map(
          (e) => e is Map<String, dynamic>
              ? e
              : (e is Map ? e.cast<String, dynamic>() : <String, dynamic>{}),
        )
        .toList();
  }
  return const [];
}

DateTime shiftDayByFourHours(DateTime input) {
  return input.subtract(const Duration(hours: _dayBoundaryHour));
}

const List<Color> _deferredPalette = [
  Color(0xFFFFCDD2),
  Color(0xFFFFF9C4),
  Color(0xFFC5CAE9),
  Color(0xFFB2DFDB),
  Color(0xFFFFE0B2),
  Color(0xFFD1C4E9),
  Color(0xFFFFF59D),
  Color(0xFFA5D6A7),
  Color(0xFFFFCCBC),
  Color(0xFFB39DDB),
];

Color _paletteColorFor(String note) {
  if (note.isEmpty) return _deferredPalette.first;
  final hash = note.hashCode & 0x7fffffff;
  return _deferredPalette[hash % _deferredPalette.length];
}

Color deferredBaseColor(String note) => _paletteColorFor(note);

Color deferredTileColor(String note) {
  final base = deferredBaseColor(note);
  return Color.lerp(base, Colors.white, 0.35)!;
}

Color deferredBorderColor(String note) {
  final base = deferredBaseColor(note);
  return Color.lerp(base, Colors.brown.shade700, 0.3)!;
}

Color deferredTextColor(String note) {
  final bg = deferredTileColor(note);
  return bg.computeLuminance() > 0.7 ? Colors.brown.shade800 : Colors.white;
}
