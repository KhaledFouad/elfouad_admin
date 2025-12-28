class Product {
  final String id;
  final String type; // 'single' | 'ready_blend' | 'drink'
  final String name;
  final String? roast;
  final String? family;
  final double? pricePerKg;
  final double? costPerKg;
  final double? pricePerCup;
  final double? costPerCup;
  final double stockGrams; // drinks may set 0
  final double? stockCups; // drinks only
  Product({
    required this.id,
    required this.type,
    required this.name,
    this.roast,
    this.family,
    this.pricePerKg,
    this.costPerKg,
    this.pricePerCup,
    this.costPerCup,
    required this.stockGrams,
    this.stockCups,
  });
}
