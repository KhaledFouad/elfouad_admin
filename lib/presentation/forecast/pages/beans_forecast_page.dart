import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/core/widgets/branded_appbar.dart';
import 'package:elfouad_admin/presentation/recipes/models/recipe_component.dart';
import 'package:elfouad_admin/presentation/recipes/models/recipe_list_item.dart';
import 'package:elfouad_admin/presentation/stats/models/stats_models.dart'
    as stats;
import 'package:elfouad_admin/presentation/stats/utils/stats_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:responsive_framework/responsive_framework.dart';

class BeansForecastPage extends StatefulWidget {
  const BeansForecastPage({super.key});

  @override
  State<BeansForecastPage> createState() => _BeansForecastPageState();
}

class _BeansForecastPageState extends State<BeansForecastPage> {
  static const int _maxDays = 3650;

  final TextEditingController _analysisCtrl = TextEditingController(text: '50');
  final TextEditingController _coverageCtrl = TextEditingController(text: '15');

  bool _loading = false;
  Object? _error;
  DateTimeRange? _range;
  List<_ForecastRow> _rows = const [];
  List<_BlendComponentForecastRow> _componentRows = const [];
  int _analysisDays = 50;
  int _coverageDays = 15;

  @override
  void initState() {
    super.initState();
    _runForecast();
  }

  @override
  void dispose() {
    _analysisCtrl.dispose();
    _coverageCtrl.dispose();
    super.dispose();
  }

  int _parseDays(String raw, int fallback) {
    final parsed = int.tryParse(raw.trim());
    final value = parsed ?? fallback;
    if (value < 1) return 1;
    if (value > _maxDays) return _maxDays;
    return value;
  }

  DateTimeRange _computeRange(int analysisDays) {
    final now = DateTime.now();
    final today4 = DateTime(now.year, now.month, now.day, 4);
    final endLocal =
        now.isBefore(today4) ? today4 : today4.add(const Duration(days: 1));
    final startLocal = endLocal.subtract(Duration(days: analysisDays));
    return DateTimeRange(start: startLocal, end: endLocal);
  }

  String _normalizeKey(String input) {
    final cleaned = input.trim().toLowerCase();
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _componentTitle(RecipeComponent component) {
    final name = component.name.trim();
    final variant = component.variant.trim();
    if (name.isEmpty) return AppStrings.noNameLabel;
    return variant.isEmpty ? name : '$name - $variant';
  }

  Future<List<RecipeListItem>> _fetchRecipes() async {
    final snap =
        await FirebaseFirestore.instance.collection('recipes').get();
    return snap.docs.map(RecipeListItem.fromSnapshot).toList();
  }

  Future<void> _runForecast() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final analysisDays = _parseDays(_analysisCtrl.text, _analysisDays);
    final coverageDays = _parseDays(_coverageCtrl.text, _coverageDays);
    final range = _computeRange(analysisDays);

    setState(() {
      _loading = true;
      _error = null;
      _analysisDays = analysisDays;
      _coverageDays = coverageDays;
      _range = range;
    });

    try {
      final raw = await fetchSalesRawForRange(
        startLocal: range.start,
        endLocal: range.end,
      );
      final prepared = prepareStatsData(raw);
      final beans = buildBeansRows(
        prepared,
        startUtc: range.start.toUtc(),
        endUtc: range.end.toUtc(),
      );
      final rows = beans
          .where((b) => b.grams > 0)
          .map((b) => _ForecastRow.fromGroupRow(b, analysisDays, coverageDays))
          .toList()
        ..sort((a, b) => b.forecastGrams.compareTo(a.forecastGrams));

      final recipes = await _fetchRecipes();
      final recipeByKey = <String, RecipeListItem>{};
      for (final recipe in recipes) {
        final key = _normalizeKey(recipe.title);
        if (key.isNotEmpty) {
          recipeByKey[key] = recipe;
        }
      }

      final forecastByKey = <String, _ForecastRow>{};
      for (final row in rows) {
        final key = _normalizeKey(row.name);
        if (key.isNotEmpty) {
          forecastByKey[key] = row;
        }
      }

      final componentRows = <_BlendComponentForecastRow>[];
      for (final entry in recipeByKey.entries) {
        final forecastRow = forecastByKey[entry.key];
        if (forecastRow == null || forecastRow.forecastGrams <= 0) continue;
        final recipe = entry.value;
        for (final component in recipe.components) {
          final percent = component.percent;
          if (percent <= 0) continue;
          final grams =
              forecastRow.forecastGrams * (percent / 100.0);
          if (grams <= 0) continue;
          componentRows.add(
            _BlendComponentForecastRow(
              blendName: recipe.title,
              componentName: _componentTitle(component),
              percent: percent,
              forecastGrams: grams,
            ),
          );
        }
      }
      componentRows.sort((a, b) {
        final c = a.blendName.compareTo(b.blendName);
        if (c != 0) return c;
        return b.forecastGrams.compareTo(a.forecastGrams);
      });

      setState(() {
        _rows = rows;
        _componentRows = componentRows;
        _loading = false;
      });
      _analysisCtrl.text = analysisDays.toString();
      _coverageCtrl.text = coverageDays.toString();
    } catch (e) {
      setState(() {
        _rows = const [];
        _componentRows = const [];
        _loading = false;
        _error = e;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final maxWidth = breakpoints.largerThan(TABLET) ? 960.0 : double.infinity;
    final horizontalPadding = isPhone ? 12.0 : 20.0;

    final totalGrams = _rows.fold<double>(
      0,
      (total, r) => total + r.gramsInRange,
    );
    final avgDaily = _analysisDays > 0 ? totalGrams / _analysisDays : 0.0;
    final forecastTotalKg =
        _analysisDays > 0 ? (avgDaily * _coverageDays) / 1000.0 : 0.0;

    return Scaffold(
      appBar: const BrandedAppBar(
        title: AppStrings.tabForecast,
        showMenu: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              10,
              horizontalPadding,
              20,
            ),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.forecastTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _analysisCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: AppStrings.forecastAnalysisDaysLabel,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _coverageCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: AppStrings.forecastCoverageDaysLabel,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: _loading ? null : _runForecast,
                            child: const Text(AppStrings.forecastRun),
                          ),
                          if (_range != null)
                            Text(
                              '${AppStrings.forecastRangeLabel}: '
                              '${_formatDate(_range!.start)} - '
                              '${_formatDate(_range!.end)}',
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        AppStrings.forecastNote,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.forecastResultsTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _StatPill(
                            label: AppStrings.forecastUsedGramsLabel,
                            value: totalGrams.toStringAsFixed(0),
                          ),
                          _StatPill(
                            label: AppStrings.forecastAvgDailyLabel,
                            value: avgDaily.toStringAsFixed(1),
                          ),
                          _StatPill(
                            label: AppStrings.forecastNeedKgLabel,
                            value: forecastTotalKg.toStringAsFixed(2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        Text(
                          AppStrings.loadFailed(
                            AppStrings.forecastTitle,
                            _error ?? 'unknown',
                          ),
                        )
                      else if (_rows.isEmpty)
                        const Text(AppStrings.forecastNoData)
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 48,
                            columns: const [
                              DataColumn(label: Text(AppStrings.itemLabel)),
                              DataColumn(
                                label: Text(AppStrings.forecastUsedGramsLabel),
                              ),
                              DataColumn(
                                label: Text(AppStrings.forecastAvgDailyLabel),
                              ),
                              DataColumn(
                                label: Text(AppStrings.forecastNeedKgLabel),
                              ),
                            ],
                            rows: _rows.map((r) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        r.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(r.gramsInRange.toStringAsFixed(0)),
                                  ),
                                  DataCell(
                                    Text(r.avgDailyGrams.toStringAsFixed(1)),
                                  ),
                                  DataCell(
                                    Text(r.forecastKg.toStringAsFixed(2)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.forecastBlendComponentsTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        Text(
                          AppStrings.loadFailed(
                            AppStrings.forecastBlendComponentsTitle,
                            _error ?? 'unknown',
                          ),
                        )
                      else if (_componentRows.isEmpty)
                        const Text(AppStrings.forecastNoBlendComponents)
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 48,
                            columns: const [
                              DataColumn(
                                label: Text(AppStrings.forecastBlendLabel),
                              ),
                              DataColumn(
                                label: Text(AppStrings.forecastComponentLabel),
                              ),
                              DataColumn(
                                label: Text(AppStrings.forecastPercentLabel),
                              ),
                              DataColumn(
                                label: Text(AppStrings.forecastComponentKgLabel),
                              ),
                            ],
                            rows: _componentRows.map((r) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        r.blendName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        r.componentName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(r.percent.toStringAsFixed(1)),
                                  ),
                                  DataCell(
                                    Text(r.forecastKg.toStringAsFixed(2)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForecastRow {
  final String name;
  final double gramsInRange;
  final double avgDailyGrams;
  final double forecastGrams;

  _ForecastRow({
    required this.name,
    required this.gramsInRange,
    required this.avgDailyGrams,
    required this.forecastGrams,
  });

  double get forecastKg => forecastGrams / 1000.0;

  factory _ForecastRow.fromGroupRow(
    stats.GroupRow row,
    int analysisDays,
    int coverageDays,
  ) {
    final safeDays = analysisDays <= 0 ? 1 : analysisDays;
    final avgDaily = row.grams / safeDays;
    final forecast = avgDaily * coverageDays;
    final name = row.key.trim().isEmpty ? AppStrings.noNameLabel : row.key;
    return _ForecastRow(
      name: name,
      gramsInRange: row.grams,
      avgDailyGrams: avgDaily,
      forecastGrams: forecast,
    );
  }
}

class _BlendComponentForecastRow {
  final String blendName;
  final String componentName;
  final double percent;
  final double forecastGrams;

  const _BlendComponentForecastRow({
    required this.blendName,
    required this.componentName,
    required this.percent,
    required this.forecastGrams,
  });

  double get forecastKg => forecastGrams / 1000.0;
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
