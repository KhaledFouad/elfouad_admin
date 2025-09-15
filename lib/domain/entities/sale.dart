class Sale {
  final DateTime createdAt;
  final String type; // 'drink' | 'single' | 'ready_blend' | 'custom_blend'
  final String name;
  final String? variant;
  final double totalPrice;
  final double totalCost;
  final bool isComplimentary;

  // drink
  final double? quantity; // cups
  final String? drinkType; // Turkish, French, Espresso...

  // beans
  final double? grams;
  final double? totalGramsForCustom;
  final String? blendFamily; // Classic, Custom, Special
  final String? singleOrigin; // Brazil, Ethiopia,...

  Sale({
    required this.createdAt,
    required this.type,
    required this.name,
    this.variant,
    required this.totalPrice,
    required this.totalCost,
    required this.isComplimentary,
    this.quantity,
    this.drinkType,
    this.grams,
    this.totalGramsForCustom,
    this.blendFamily,
    this.singleOrigin,
  });
}