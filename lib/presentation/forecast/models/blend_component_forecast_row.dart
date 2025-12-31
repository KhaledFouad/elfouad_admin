class BlendComponentForecastRow {
  const BlendComponentForecastRow({
    required this.componentName,
    required this.forecastGrams,
    required this.blendGrams,
  });

  final String componentName;
  final double forecastGrams;
  final double blendGrams;

  double get forecastKg => forecastGrams / 1000.0;
  double get blendKg => blendGrams / 1000.0;
}
