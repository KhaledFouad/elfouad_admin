import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/stats/models/stats_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SalesProfitTrendChart extends StatelessWidget {
  const SalesProfitTrendChart({
    super.key,
    required this.sales,
    required this.profit,
  });

  final List<DayVal> sales;
  final List<DayVal> profit;

  @override
  Widget build(BuildContext context) {
    final all = [...sales, ...profit];
    if (all.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text(AppStrings.noDataForRange)),
      );
    }

    final x = _xRange(all);
    final maxY = _maxYFrom(all);
    final salesSpots = _toSpots(sales);
    final profitSpots = _toSpots(profit);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: const [
              _LegendDot(
                color: Color(0xFF1E88E5),
                label: AppStrings.salesLabelDefinite,
              ),
              _LegendDot(
                color: Color(0xFF43A047),
                label: AppStrings.profitLabelDefinite,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minX: x.minX,
              maxX: x.maxX,
              minY: 0,
              maxY: maxY * 1.2,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: _titlesData(
                minX: x.minX,
                maxX: x.maxX,
                integerLeft: false,
              ),
              lineTouchData: _salesProfitTooltip(),
              lineBarsData: [
                _line(salesSpots, const Color(0xFF1E88E5), 3),
                _line(profitSpots, const Color(0xFF43A047), 3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LineTouchData _salesProfitTooltip() {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (spots) {
          return spots.map((s) {
            final date = _formatDay(s.x);
            final label = s.barIndex == 0
                ? AppStrings.salesLabelDefinite
                : AppStrings.profitLabelDefinite;
            return LineTooltipItem(
              '$date\n$label: ${s.y.toStringAsFixed(2)}',
              const TextStyle(color: Colors.white),
            );
          }).toList();
        },
      ),
    );
  }
}

class DetailTrendChart extends StatelessWidget {
  const DetailTrendChart({
    super.key,
    required this.primary,
    required this.sales,
    required this.profit,
    required this.primaryLegend,
    required this.primaryTooltipLabel,
    required this.primaryColor,
    this.primaryAsInt = false,
  });

  final List<DayVal> primary;
  final List<DayVal> sales;
  final List<DayVal> profit;
  final String primaryLegend;
  final String primaryTooltipLabel;
  final Color primaryColor;
  final bool primaryAsInt;

  @override
  Widget build(BuildContext context) {
    if (primary.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text(AppStrings.noDataForRange)),
      );
    }

    final x = _xRange(primary);
    final maxY = _maxYFrom(primary);
    final primarySpots = _toSpots(primary);

    final salesByDay = _byDayKey(sales);
    final profitByDay = _byDayKey(profit);
    final primaryByDay = _byDayKey(primary);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [_LegendDot(color: primaryColor, label: primaryLegend)],
          ),
        ),
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minX: x.minX,
              maxX: x.maxX,
              minY: 0,
              maxY: maxY * 1.2,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: _titlesData(
                minX: x.minX,
                maxX: x.maxX,
                integerLeft: primaryAsInt,
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) {
                    return spots.map((s) {
                      final dayKey = s.x.round();
                      final date = _formatDay(s.x);
                      final primaryValue = primaryByDay[dayKey] ?? s.y;
                      final salesValue = salesByDay[dayKey] ?? 0.0;
                      final profitValue = profitByDay[dayKey] ?? 0.0;
                      final primaryText = primaryAsInt
                          ? primaryValue.toStringAsFixed(0)
                          : primaryValue.toStringAsFixed(2);
                      return LineTooltipItem(
                        '$date\n'
                        '$primaryTooltipLabel: $primaryText\n'
                        '${AppStrings.salesLabelDefinite}: ${salesValue.toStringAsFixed(2)}\n'
                        '${AppStrings.profitLabelDefinite}: ${profitValue.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [_line(primarySpots, primaryColor, 3)],
            ),
          ),
        ),
      ],
    );
  }
}

({double minX, double maxX}) _xRange(List<DayVal> series) {
  final xs = series
      .map((e) => e.day.millisecondsSinceEpoch.toDouble())
      .toList();
  var minX = xs.reduce((a, b) => a < b ? a : b);
  var maxX = xs.reduce((a, b) => a > b ? a : b);
  if (minX == maxX) {
    const pad = 12 * 60 * 60 * 1000.0;
    minX -= pad;
    maxX += pad;
  }
  return (minX: minX, maxX: maxX);
}

double _maxYFrom(List<DayVal> series) {
  var maxY = 0.0;
  for (final v in series) {
    if (v.v > maxY) maxY = v.v;
  }
  return maxY <= 0 ? 1.0 : maxY;
}

Map<int, double> _byDayKey(List<DayVal> series) {
  final out = <int, double>{};
  for (final entry in series) {
    out[entry.day.millisecondsSinceEpoch] = entry.v;
  }
  return out;
}

FlTitlesData _titlesData({
  required double minX,
  required double maxX,
  required bool integerLeft,
}) {
  const dayMs = 86400000.0;
  final span = (maxX - minX).abs();
  final safeInterval = span < dayMs ? dayMs : span / 4;

  return FlTitlesData(
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        getTitlesWidget: (v, meta) => Text(
          integerLeft ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
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
          return Text('$dd/$mm', style: const TextStyle(fontSize: 10));
        },
      ),
    ),
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

List<FlSpot> _toSpots(List<DayVal> values) {
  return values
      .map((e) => FlSpot(e.day.millisecondsSinceEpoch.toDouble(), e.v))
      .toList()
    ..sort((a, b) => a.x.compareTo(b.x));
}

String _formatDay(double x) {
  final d = DateTime.fromMillisecondsSinceEpoch(x.toInt());
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd/$mm';
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
