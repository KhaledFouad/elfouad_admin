import 'package:elfouad_admin/presentation/admin/dashboard/providers.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class Trends extends StatefulWidget {
  final List<DayPoint> sales;
  final List<DayPoint> profit;
  const Trends({super.key, required this.sales, required this.profit});

  @override
  State<Trends> createState() => _TrendsState();
}

class _TrendsState extends State<Trends> {
  bool showProfit = false;

  @override
  Widget build(BuildContext context) {
    final points = showProfit ? widget.profit : widget.sales;
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'الاتجاهات — ${showProfit ? 'الربح' : 'المبيعات'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('مبيعات')),
                    ButtonSegment(value: true, label: Text('ربح')),
                  ],
                  selected: {showProfit},
                  onSelectionChanged: (s) =>
                      setState(() => showProfit = s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      spots: spots,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
