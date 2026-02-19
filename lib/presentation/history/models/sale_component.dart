import 'package:elfouad_admin/core/utils/app_strings.dart';

class SaleComponent {
  const SaleComponent({
    required this.name,
    required this.variant,
    required this.grams,
    required this.quantity,
    required this.unit,
    required this.lineTotalPrice,
    required this.lineTotalCost,
    this.spiced,
    this.ginsengGrams = 0,
    this.spicedEnabled,
  });

  final String name;
  final String variant;
  final double grams;
  final double quantity;
  final String unit;
  final double lineTotalPrice;
  final double lineTotalCost;
  final bool? spiced;
  final int ginsengGrams;
  final bool? spicedEnabled;

  String get label => variant.isNotEmpty ? '$name - $variant' : name;

  String quantityLabel(String Function(String value) translateUnit) {
    if (grams > 0) {
      return '${grams.toStringAsFixed(0)} ${AppStrings.unitGrams}';
    }
    if (quantity <= 0) {
      return '';
    }
    final normalizedUnit = unit.isEmpty ? '' : translateUnit(unit);
    return '$quantity $normalizedUnit'.trim();
  }

  SaleComponent copyWith({
    String? name,
    String? variant,
    double? grams,
    double? quantity,
    String? unit,
    double? lineTotalPrice,
    double? lineTotalCost,
    bool? spiced,
    int? ginsengGrams,
    bool? spicedEnabled,
  }) {
    return SaleComponent(
      name: name ?? this.name,
      variant: variant ?? this.variant,
      grams: grams ?? this.grams,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lineTotalPrice: lineTotalPrice ?? this.lineTotalPrice,
      lineTotalCost: lineTotalCost ?? this.lineTotalCost,
      spiced: spiced ?? this.spiced,
      spicedEnabled: spicedEnabled ?? this.spicedEnabled,

      ginsengGrams: ginsengGrams ?? this.ginsengGrams,
    );
  }

  static SaleComponent fromMap(Map<String, dynamic> map) {
    final meta = map['meta'];
    final metaMap = meta is Map
        ? meta.cast<String, dynamic>()
        : const <String, dynamic>{};
    var spicedEnabled = _readBool(
      metaMap['spicedEnabled'] ?? map['spicedEnabled'],
    );
    final spicedValue = _readBool(metaMap['spiced'] ?? map['spiced']);
    if (spicedEnabled == null && spicedValue == true) {
      spicedEnabled = true;
    }
    final spiced = spicedEnabled == true ? (spicedValue ?? false) : null;
    final ginseng = _parseInt(metaMap['ginseng_grams'] ?? map['ginseng_grams']);
    return SaleComponent(
      name: (map['name'] ?? map['item_name'] ?? map['product_name'] ?? '')
          .toString(),
      variant: (map['variant'] ?? map['roast'] ?? '').toString(),
      grams: _parseDouble(map['grams'] ?? map['weight']),
      quantity: _parseDouble(map['qty'] ?? map['count']),
      unit: (map['unit'] ?? '').toString(),
      lineTotalPrice: _parseDouble(
        map['line_total_price'] ?? map['total_price'],
      ),
      lineTotalCost: _parseDouble(map['line_total_cost'] ?? map['total_cost']),
      spiced: spiced,
      ginsengGrams: ginseng,
      spicedEnabled: spicedEnabled,
    );
  }

  static bool? _readBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = value.toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return null;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
