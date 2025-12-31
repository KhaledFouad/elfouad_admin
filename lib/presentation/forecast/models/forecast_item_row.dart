class ForecastItemRow {
  const ForecastItemRow({
    required this.key,
    required this.name,
    required this.type,
    required this.gramsInRange,
    required this.avgDailyGrams,
    required this.forecastGrams,
  });

  final String key;
  final String name;
  final String type;
  final double gramsInRange;
  final double avgDailyGrams;
  final double forecastGrams;

  double get forecastKg => forecastGrams / 1000.0;
}
