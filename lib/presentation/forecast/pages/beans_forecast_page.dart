import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/core/widgets/branded_appbar.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:elfouad_admin/presentation/recipes/models/recipe_list_item.dart';
import 'package:elfouad_admin/presentation/stats/utils/stats_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../models/blend_component_forecast_row.dart';
import '../models/forecast_item_row.dart';
import '../utils/blend_component_utils.dart';
import '../utils/forecast_utils.dart';
import '../widgets/forecast_stat_pill.dart';

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
  List<ForecastItemRow> _rows = const [];
  List<BlendComponentForecastRow> _componentRows = const [];
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
    final endLocal = now.isBefore(today4)
        ? today4
        : today4.add(const Duration(days: 1));
    final startLocal = endLocal.subtract(Duration(days: analysisDays));
    return DateTimeRange(start: startLocal, end: endLocal);
  }

  Future<List<RecipeListItem>> _fetchRecipes() async {
    final snap = await FirebaseFirestore.instance.collection('recipes').get();
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
      final seriesByKey = buildBeanDailySeries(
        prepared,
        startUtc: range.start.toUtc(),
        endUtc: range.end.toUtc(),
        analysisDays: analysisDays,
      );
      final rows = <ForecastItemRow>[];
      seriesByKey.forEach((_, series) {
        final stats = forecastSeries(series.dailyGrams, coverageDays);
        if (stats.totalGrams <= 0 && stats.forecastGrams <= 0) return;
        rows.add(
          ForecastItemRow(
            key: series.key,
            name: series.name,
            type: series.type,
            gramsInRange: stats.totalGrams,
            avgDailyGrams: stats.avgDailyForecast,
            forecastGrams: stats.forecastGrams,
          ),
        );
      });
      rows.sort((a, b) => b.forecastGrams.compareTo(a.forecastGrams));

      final recipes = await _fetchRecipes();
      final blendForecastByKey = <String, ForecastItemRow>{};
      for (final row in rows) {
        if (row.type != 'ready_blend' || row.forecastGrams <= 0) continue;
        if (row.key.isNotEmpty) {
          blendForecastByKey[row.key] = row;
        }
      }

      final componentRows = buildBlendComponentForecastRows(
        recipes: recipes,
        blendForecastByKey: blendForecastByKey,
      );

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
    final forecastTotalGrams = _rows.fold<double>(
      0,
      (total, r) => total + r.forecastGrams,
    );
    final avgDaily = _coverageDays > 0
        ? (forecastTotalGrams / _coverageDays)
        : 0.0;
    final forecastTotalKg = forecastTotalGrams / 1000.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: AppBar(
            centerTitle: true,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.home_rounded, color: Colors.white),
              onPressed: () => context.read<NavCubit>().setTab(AppTab.home),
              tooltip: AppStrings.tabHome,
            ),
            title: const Text(
              AppStrings.forecastTitle,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 35,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.transparent,

            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5D4037), Color(0xFF795548)],
                ),
              ),
            ),
          ),
        ),
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
                          ForecastStatPill(
                            label: AppStrings.forecastUsedGramsLabel,
                            value: totalGrams.toStringAsFixed(0),
                          ),
                          ForecastStatPill(
                            label: AppStrings.forecastAvgDailyLabel,
                            value: avgDaily.toStringAsFixed(1),
                          ),
                          ForecastStatPill(
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
                                label: Text(AppStrings.forecastComponentLabel),
                              ),
                              DataColumn(
                                label: Text(
                                  AppStrings.forecastBlendTotalKgLabel,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppStrings.forecastComponentKgLabel,
                                ),
                              ),
                            ],
                            rows: _componentRows.map((r) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        r.componentName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(r.blendKg.toStringAsFixed(2))),
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
