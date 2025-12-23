import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elfouad_admin/core/app_strings.dart';

import '../state/stats_data_provider.dart';

class StatsHighlightsCard extends StatelessWidget {
  final StatsHighlights highlights;
  const StatsHighlightsCard({super.key, required this.highlights});

  String _formatDay(DateTime d) {
    return DateFormat('EEE d MMM', 'ar').format(d.toLocal());
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatNumber(double value, {int decimals = 1}) {
    return value.toStringAsFixed(decimals);
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.brown.shade50,
        child: Icon(icon, color: Colors.brown.shade700, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    final topSales = highlights.topSalesDay;
    if (topSales != null) {
      final subtitleParts = <String>[_formatDay(topSales.day)];
      if (topSales.orders > 0) {
        subtitleParts.add(AppStrings.operationsCount(topSales.orders));
      }
      tiles.add(
        _buildTile(
          icon: Icons.bar_chart,
          title: AppStrings.topDailySalesTitle,
          value: _formatCurrency(topSales.sales),
          subtitle: subtitleParts.join(' • '),
        ),
      );
    }

    final topProfit = highlights.topProfitDay;
    if (topProfit != null) {
      final subtitleParts = <String>[_formatDay(topProfit.day)];
      if (topProfit.orders > 0) {
        subtitleParts.add(AppStrings.operationsCount(topProfit.orders));
      }
      tiles.add(
        _buildTile(
          icon: Icons.trending_up,
          title: AppStrings.topDailyProfitTitle,
          value: _formatCurrency(topProfit.profit),
          subtitle: subtitleParts.join(' • '),
        ),
      );
    }

    final busiest = highlights.busiestDay;
    if (busiest != null) {
      tiles.add(
        _buildTile(
          icon: Icons.local_cafe,
          title: AppStrings.busiestDayTitle,
          value: AppStrings.unitsCount(busiest.servings),
          subtitle: _formatDay(busiest.day),
        ),
      );
    }

    tiles.add(
      _buildTile(
        icon: Icons.calendar_month,
        title: AppStrings.averageDailySalesTitle,
        value: _formatCurrency(highlights.averageDailySales),
        subtitle: highlights.activeDays > 0
            ? AppStrings.activeDaysSubtitle(highlights.activeDays)
            : null,
      ),
    );

    tiles.add(
      _buildTile(
        icon: Icons.coffee_outlined,
        title: AppStrings.averageDrinksPerDayTitle,
        value: _formatNumber(highlights.averageDrinksPerDay, decimals: 1),
      ),
    );

    tiles.add(
      _buildTile(
        icon: Icons.cookie_outlined,
        title: AppStrings.averageSnacksPerDayTitle,
        value: _formatNumber(highlights.averageSnacksPerDay, decimals: 1),
      ),
    );

    tiles.add(
      _buildTile(
        icon: Icons.point_of_sale,
        title: AppStrings.averageOrdersPerDayTitle,
        value: _formatNumber(highlights.averageOrdersPerDay, decimals: 1),
        subtitle: highlights.totalOrders > 0
            ? AppStrings.paidOrdersSubtitle(highlights.totalOrders)
            : null,
      ),
    );

    return Column(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          tiles[i],
        ],
      ],
    );
  }
}
