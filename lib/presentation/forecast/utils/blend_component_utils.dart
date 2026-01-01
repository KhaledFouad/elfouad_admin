import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/recipes/models/recipe_component.dart';
import 'package:elfouad_admin/presentation/recipes/models/recipe_list_item.dart';

import '../models/blend_component_forecast_row.dart';
import '../models/forecast_item_row.dart';
import 'forecast_utils.dart';

List<BlendComponentForecastRow> buildBlendComponentForecastRows({
  required List<RecipeListItem> recipes,
  required Map<String, ForecastItemRow> blendForecastByKey,
}) {
  final totals = <String, _ComponentAccumulator>{};

  for (final recipe in recipes) {
    final blendKey = normalizeKey(recipe.title);
    if (blendKey.isEmpty) continue;
    final forecast = blendForecastByKey[blendKey];
    if (forecast == null || forecast.forecastGrams <= 0) continue;

    for (final component in recipe.components) {
      final percent = component.percent;
      if (percent <= 0) continue;
      final grams = forecast.forecastGrams * (percent / 100.0);
      if (grams <= 0) continue;

      final title = _componentTitle(component);
      final key = normalizeKey(title);
      if (key.isEmpty) continue;

      final acc = totals.putIfAbsent(
        key,
        () => _ComponentAccumulator(componentName: title),
      );
      acc.add(
        componentGrams: grams,
        blendGrams: forecast.forecastGrams,
        blendKey: blendKey,
      );
    }
  }

  final rows =
      totals.values
          .map(
            (acc) => BlendComponentForecastRow(
              componentName: acc.componentName,
              forecastGrams: acc.componentGrams,
              blendGrams: acc.blendGrams,
            ),
          )
          .toList()
        ..sort((a, b) => b.forecastGrams.compareTo(a.forecastGrams));

  return rows;
}

String _componentTitle(RecipeComponent component) {
  final name = component.name.trim();
  final variant = component.variant.trim();
  if (name.isEmpty) return AppStrings.noNameLabel;
  return variant.isEmpty ? name : '$name - $variant';
}

class _ComponentAccumulator {
  _ComponentAccumulator({required this.componentName});

  final String componentName;
  double componentGrams = 0.0;
  double blendGrams = 0.0;
  final Set<String> _blendKeys = {};

  void add({
    required double componentGrams,
    required double blendGrams,
    required String blendKey,
  }) {
    this.componentGrams += componentGrams;
    if (_blendKeys.add(blendKey)) {
      this.blendGrams += blendGrams;
    }
  }
}
