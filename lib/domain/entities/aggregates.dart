class DrinkAgg {
  final String type;
  final int cups;
  final double sales;
  final double cost;
  double get profit => sales - cost;
  double get avgPrice => cups > 0 ? sales / cups : 0;
  const DrinkAgg({required this.type, required this.cups, required this.sales, required this.cost});
}
class BeansAgg {
  final String family;
  final double grams;
  final double sales;
  final double cost;
  double get profit => sales - cost;
  double get avgPerKg => grams > 0 ? (sales / grams) * 1000 : 0;
  const BeansAgg({required this.family, required this.grams, required this.sales, required this.cost});
}
