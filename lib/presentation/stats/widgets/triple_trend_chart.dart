import 'package:elfouad_admin/presentation/stats/state/stats_data_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TripleTrendChart extends StatelessWidget {
  final List<DayVal> line1; // إجمالي (مبيعات/ربح)
  final List<DayVal> lineDrinks; // مبيعات المشروبات
  final List<DayVal> lineBeansGrams; // جرامات البن
  final bool asProfit;
  const TripleTrendChart({
    super.key,
    required this.line1,
    required this.lineDrinks,
    required this.lineBeansGrams,
    required this.asProfit,
  });

  @override
  Widget build(BuildContext context) {
    if (line1.isEmpty && lineDrinks.isEmpty && lineBeansGrams.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('لا بيانات')),
      );
    }

    final allDays = <DateTime>{
      ...line1.map((e) => e.day),
      ...lineDrinks.map((e) => e.day),
      ...lineBeansGrams.map((e) => e.day),
    }.toList()..sort();

    List<FlSpot> spots(List<DayVal> l) {
      final map = {
        for (var i = 0; i < allDays.length; i++) allDays[i]: i.toDouble(),
      };
      return l.map((e) => FlSpot(map[e.day]!, e.v)).toList();
    }

    double maxY(List<DayVal> a, List<DayVal> b, List<DayVal> c) {
      double m = 0;
      for (final v in [...a, ...b, ...c]) {
        if (v.v > m) m = v.v;
      }
      return m == 0 ? 1 : m * 1.15;
    }

    LineChartBarData series(List<DayVal> l, Color c) => LineChartBarData(
      spots: spots(l),
      isCurved: true,
      barWidth: 3,
      color: c,
      dotData: FlDotData(show: false),
    );

    return SizedBox(
      height: 260,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (allDays.length - 1).toDouble(),
            minY: 0,
            maxY: maxY(line1, lineDrinks, lineBeansGrams),
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= allDays.length) {
                      return const SizedBox.shrink();
                    }
                    final d = allDays[i];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, m) => Text(
                    v.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => Colors.brown,
                getTooltipItems: (spots) {
                  if (spots.isEmpty) return [];
                  final i = spots.first.x.toInt().clamp(0, allDays.length - 1);
                  final d = allDays[i];
                  final dd =
                      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                  return [
                    LineTooltipItem(
                      '$dd — ${spots.first.y.toStringAsFixed(2)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ];
                },
              ),
            ),
            lineBarsData: [
              series(line1, const Color(0xFF00838F)), // إجمالي
              series(lineDrinks, const Color(0xFF6A1B9A)), // مشروبات
              series(lineBeansGrams, const Color(0xFF2E7D32)), // جرامات
            ],
          ),
        ),
      ),
    );
  }
}
