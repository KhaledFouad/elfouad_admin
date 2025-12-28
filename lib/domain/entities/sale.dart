class Sale {
  final DateTime createdAt;
  final String type;
  final String name;
  final String? drinkName;
  final String? variant;
  final double totalPrice;
  final double totalCost;
  final bool isComplimentary;
  final bool isSpiced;
  final double? quantity;
  final String? drinkType;
  final double? grams;
  final double? totalGramsForCustom;
  final String? blendFamily;
  final String? singleOrigin;
  Sale({
    required this.createdAt,
    required this.type,
    required this.name,
    this.drinkName,
    this.variant,
    required this.totalPrice,
    required this.totalCost,
    required this.isComplimentary,
    required this.isSpiced,
    this.quantity,
    this.drinkType,
    this.grams,
    this.totalGramsForCustom,
    this.blendFamily,
    this.singleOrigin,
  });
}
