import 'package:elfouad_admin/core/app_strings.dart';

class SaleComponent {
  const SaleComponent({
    required this.name,
    required this.variant,
    required this.grams,
    required this.quantity,
    required this.unit,
    required this.lineTotalPrice,
    required this.lineTotalCost,
  });

  final String name;
  final String variant;
  final double grams;
  final double quantity;
  final String unit;
  final double lineTotalPrice;
  final double lineTotalCost;

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
  }) {
    return SaleComponent(
      name: name ?? this.name,
      variant: variant ?? this.variant,
      grams: grams ?? this.grams,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lineTotalPrice: lineTotalPrice ?? this.lineTotalPrice,
      lineTotalCost: lineTotalCost ?? this.lineTotalCost,
    );
  }

  static SaleComponent fromMap(Map<String, dynamic> map) {
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
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
