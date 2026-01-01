String composeStocktakeTitle(String name, String variant, String category) {
  if (variant.trim().isNotEmpty) {
    return '$name - $variant';
  }
  if (category.trim().isNotEmpty) {
    return '$name - $category';
  }
  return name;
}

String stocktakeUnitFor(String unit, String fallback) {
  final trimmed = unit.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

double? parseStocktakeDecimal(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.replaceAll(',', '.');
  return double.tryParse(normalized);
}

double stocktakeDoubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

int stocktakeIntValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return 0;
}

String stocktakeFormatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

String stocktakeFormatSigned(double value, String unit) {
  final sign = value >= 0 ? '+' : '-';
  return '$sign${stocktakeFormatNumber(value.abs())} $unit';
}

bool stocktakeIsZero(double value) => value.abs() < 0.0001;

double? stocktakeDiffFor({
  required bool isExtra,
  required double current,
  required double? countedInput,
}) {
  if (countedInput == null) return null;
  return isExtra ? countedInput - current : (countedInput * 1000) - current;
}

String stocktakeFormatDiff({
  required bool isExtra,
  required double diff,
  required String unit,
  required String kgUnit,
}) {
  final displayValue = isExtra ? diff : diff / 1000;
  final displayUnit = isExtra ? unit : kgUnit;
  return stocktakeFormatSigned(displayValue, displayUnit);
}
