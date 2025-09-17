import 'package:elfouad_admin/presentation/stats/state/stats_data_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
        child: Center(child: Text('لا توجد بيانات للمدى المختار')),
      );
    }

    final xs = all.map((e) => e.day.millisecondsSinceEpoch.toDouble()).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);

    double maxY = 0;
    for (final v in all) {
      if (v.v > maxY) maxY = v.v;
    }
    if (maxY <= 0) maxY = 1;

    List<FlSpot> _toSpots(List<DayVal> l) =>
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
              _legendDot(color1, asProfit ? 'الربح' : 'المبيعات'),
              _legendDot(color2, 'مشروبات (مبيعات)'),
              _legendDot(color3, 'بن (جرامات)'),
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
                    interval: (maxX - minX) / 4,
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
                _line(_toSpots(line1), color1, 3),
                _line(_toSpots(lineDrinks), color2, 2),
                _line(_toSpots(lineBeansGrams), color3, 2),
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
