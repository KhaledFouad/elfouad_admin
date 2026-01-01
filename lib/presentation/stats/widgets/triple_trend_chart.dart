import 'package:elfouad_admin/presentation/stats/models/stats_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

class TripleTrendChart extends StatelessWidget {
  final List<DayVal> line1; // إجمالي (مبيعات أو ربح)
  final List<DayVal> lineDrinks; // مبيعات المشروبات
  final List<DayVal> lineBeansGrams; // جرامات البن
  final bool asProfit; // يحدد عنوان السلسلة الأولى
  const TripleTrendChart({
    super.key,
    required this.line1,
    required this.lineDrinks,
    required this.lineBeansGrams,
    required this.asProfit,
  });

  @override
  Widget build(BuildContext context) {
    final all = [...line1, ...lineDrinks, ...lineBeansGrams];
    if (all.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text(AppStrings.noDataForRange)),
      );
    }

    final xs = all.map((e) => e.day.millisecondsSinceEpoch.toDouble()).toList();
    var minX = xs.reduce((a, b) => a < b ? a : b);
    var maxX = xs.reduce((a, b) => a > b ? a : b);
    // ✅ لو نطاق يوم واحد فقط، نزود padding 12 ساعة يمين وشمال
    const dayMs = 86400000.0; // Duration(days: 1) in ms
    if (minX == maxX) {
      const pad = 12 * 60 * 60 * 1000.0; // 12h
      minX -= pad;
      maxX += pad;
    }

    final span = (maxX - minX).abs();
    // ✅ ضمان إن الـ interval عمره ما يبقى 0
    final safeInterval = span < dayMs ? dayMs : span / 4;
    double maxY = 0;
    for (final v in all) {
      if (v.v > maxY) maxY = v.v;
    }
    if (maxY <= 0) maxY = 1;

    List<FlSpot> toSpots(List<DayVal> l) =>
        l
            .map((e) => FlSpot(e.day.millisecondsSinceEpoch.toDouble(), e.v))
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));

    final color1 = const Color(0xFF1E88E5); // أزرق للسلسلة الأولى
    final color2 = const Color(0xFF43A047); // أخضر للمشروبات
    final color3 = const Color(0xFFF4511E); // برتقالي للجرامات

    return Column(
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _legendDot(
                color1,
                asProfit
                    ? AppStrings.profitLabelDefinite
                    : AppStrings.salesLabelDefinite,
              ),
              _legendDot(color2, AppStrings.drinksSalesLegend),
              _legendDot(color3, AppStrings.beansGramsLegend),
            ],
          ),
        ),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              maxY: maxY * 1.2,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, meta) => Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: safeInterval,
                    getTitlesWidget: (v, meta) {
                      final d = DateTime.fromMillisecondsSinceEpoch(v.toInt());
                      final mm = d.month.toString().padLeft(2, '0');
                      final dd = d.day.toString().padLeft(2, '0');
                      return Text(
                        '$dd/$mm',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((s) {
                      final d = DateTime.fromMillisecondsSinceEpoch(
                        s.x.toInt(),
                      );
                      final mm = d.month.toString().padLeft(2, '0');
                      final dd = d.day.toString().padLeft(2, '0');
                      return LineTooltipItem(
                        '$dd/$mm — ${s.y.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                _line(toSpots(line1), color1, 3),
                _line(toSpots(lineDrinks), color2, 2),
                _line(toSpots(lineBeansGrams), color3, 2),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, double stroke) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: stroke,
      dotData: FlDotData(show: true),
      spots: spots,
    );
  }
}
