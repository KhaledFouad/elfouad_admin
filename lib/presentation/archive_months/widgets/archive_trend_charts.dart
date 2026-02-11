import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/archive_month.dart';

class ArchiveTrendsCard extends StatelessWidget {
  const ArchiveTrendsCard({super.key, required this.months});

  final List<ArchiveMonth> months;

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints(months);
    if (points.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text(AppStrings.noDataForRange)),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                AppStrings.archiveTrendsTitle,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            _TwoLineChart(
              title: AppStrings.archiveSalesProfitTrendTitle,
              points: points,
              label1: AppStrings.salesLabelDefinite,
              label2: AppStrings.profitLabelDefinite,
              color1: const Color(0xFF1E88E5),
              color2: const Color(0xFF43A047),
              v1: (p) => p.sales,
              v2: (p) => p.profit,
              isInt: false,
            ),
            const SizedBox(height: 12),
            _SingleLineChart(
              title: AppStrings.archiveCupsTrendTitle,
              points: points,
              label: AppStrings.cupsLabelShort,
              color: const Color(0xFFF4511E),
              v: (p) => p.cups.toDouble(),
              isInt: true,
            ),
            const SizedBox(height: 12),
            _SingleLineChart(
              title: AppStrings.archiveGramsTrendTitle,
              points: points,
              label: AppStrings.gramsLabel,
              color: const Color(0xFF6D4C41),
              v: (p) => p.grams,
              isInt: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPoint {
  final DateTime month;
  final double sales;
  final double profit;
  final int cups;
  final double grams;

  const _MonthPoint({
    required this.month,
    required this.sales,
    required this.profit,
    required this.cups,
    required this.grams,
  });
}

List<_MonthPoint> _buildPoints(List<ArchiveMonth> months) {
  final list =
      months.where((m) => m.monthDate != null && !m.summary.isEmpty).map((m) {
        final s = m.summary;
        return _MonthPoint(
          month: m.monthDate!,
          sales: s.sales ?? 0,
          profit: s.profit ?? 0,
          cups: s.drinks ?? 0,
          grams: s.grams ?? 0,
        );
      }).toList()..sort((a, b) => a.month.compareTo(b.month));
  return list;
}

class _TwoLineChart extends StatelessWidget {
  const _TwoLineChart({
    required this.title,
    required this.points,
    required this.label1,
    required this.label2,
    required this.color1,
    required this.color2,
    required this.v1,
    required this.v2,
    required this.isInt,
  });

  final String title;
  final List<_MonthPoint> points;
  final String label1;
  final String label2;
  final Color color1;
  final Color color2;
  final double Function(_MonthPoint) v1;
  final double Function(_MonthPoint) v2;
  final bool isInt;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text(AppStrings.noDataForRange)),
      );
    }

    final count = points.length;
    final spots1 = <FlSpot>[];
    final spots2 = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final y1 = v1(p);
      final y2 = v2(p);
      spots1.add(FlSpot(i.toDouble(), y1));
      spots2.add(FlSpot(i.toDouble(), y2));
      if (y1 > maxY) maxY = y1;
      if (y2 > maxY) maxY = y2;
    }
    if (maxY <= 0) maxY = 1;
    final interval = count <= 6 ? 1 : (count / 6).ceil().toDouble();

    String labelFor(int index) {
      if (index < 0 || index >= points.length) return '';
      return DateFormat('MM/yy', 'ar').format(points[index].month);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [_legendDot(color1, label1), _legendDot(color2, label2)],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (count - 1).toDouble(),
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
                    getTitlesWidget: (v, meta) {
                      final text = isInt
                          ? v.toStringAsFixed(0)
                          : v.toStringAsFixed(0);
                      return Text(text, style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final index = v.toInt();
                      if (index < 0 || index >= count) {
                        return const SizedBox.shrink();
                      }
                      if (index % interval.round() != 0 && index != count - 1) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        labelFor(index),
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
                      final index = s.x.toInt();
                      final label = labelFor(index);
                      final v = isInt
                          ? s.y.toStringAsFixed(0)
                          : s.y.toStringAsFixed(2);
                      return LineTooltipItem(
                        '$label — $v',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [_line(spots1, color1), _line(spots2, color2)],
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

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: true),
      spots: spots,
    );
  }
}

class _SingleLineChart extends StatelessWidget {
  const _SingleLineChart({
    required this.title,
    required this.points,
    required this.label,
    required this.color,
    required this.v,
    required this.isInt,
  });

  final String title;
  final List<_MonthPoint> points;
  final String label;
  final Color color;
  final double Function(_MonthPoint) v;
  final bool isInt;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text(AppStrings.noDataForRange)),
      );
    }

    final count = points.length;
    final spots = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final y = v(p);
      spots.add(FlSpot(i.toDouble(), y));
      if (y > maxY) maxY = y;
    }
    if (maxY <= 0) maxY = 1;
    final interval = count <= 6 ? 1 : (count / 6).ceil().toDouble();

    String labelFor(int index) {
      if (index < 0 || index >= points.length) return '';
      return DateFormat('MM/yy', 'ar').format(points[index].month);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: _legendDot(color, label),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (count - 1).toDouble(),
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
                    getTitlesWidget: (v, meta) {
                      final text = isInt
                          ? v.toStringAsFixed(0)
                          : v.toStringAsFixed(0);
                      return Text(text, style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final index = v.toInt();
                      if (index < 0 || index >= count) {
                        return const SizedBox.shrink();
                      }
                      if (index % interval.round() != 0 && index != count - 1) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        labelFor(index),
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
                      final index = s.x.toInt();
                      final labelText = labelFor(index);
                      final vText = isInt
                          ? s.y.toStringAsFixed(0)
                          : s.y.toStringAsFixed(2);
                      return LineTooltipItem(
                        '$labelText — $vText',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [_line(spots, color)],
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

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: true),
      spots: spots,
    );
  }
}
