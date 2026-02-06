import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

import '../models/archive_month.dart';

class ArchiveSummaryTable extends StatelessWidget {
  const ArchiveSummaryTable({
    super.key,
    required this.months,
    this.onSelect,
  });

  final List<ArchiveMonth> months;
  final ValueChanged<ArchiveMonth>? onSelect;

  String _labelFor(ArchiveMonth month) {
    final date = month.monthDate;
    if (date != null) {
      return DateFormat('MMMM yyyy', 'ar').format(date);
    }
    return month.rawLabel;
  }

  String _fmtNum(num? value, {int decimals = 2}) {
    if (value == null) return '—';
    return value.toStringAsFixed(decimals);
  }

  String _fmtInt(num? value) {
    if (value == null) return '—';
    return value.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) {
      return const Center(child: Text(AppStrings.noDataForRange));
    }

    final headerStyle = const TextStyle(fontWeight: FontWeight.w800);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        columns: [
          DataColumn(label: Text(AppStrings.monthLabel, style: headerStyle)),
          DataColumn(label: Text(AppStrings.salesLabelDefinite, style: headerStyle)),
          DataColumn(label: Text(AppStrings.profitLabelDefinite, style: headerStyle)),
          DataColumn(label: Text(AppStrings.gramsLabel, style: headerStyle)),
          DataColumn(label: Text(AppStrings.cupsLabelShort, style: headerStyle)),
          DataColumn(label: Text(AppStrings.snacksLabel, style: headerStyle)),
        ],
        rows: months.asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;
          final s = m.summary;
          final prev = i + 1 < months.length ? months[i + 1].summary : null;
          return DataRow(
            onSelectChanged: onSelect == null ? null : (_) => onSelect!(m),
            cells: [
              DataCell(Text(_labelFor(m))),
              DataCell(
                _metricCell(
                  _fmtNum(s.sales),
                  current: s.sales ?? 0,
                  previous: prev?.sales ?? 0,
                ),
              ),
              DataCell(
                _metricCell(
                  _fmtNum(s.profit),
                  current: s.profit ?? 0,
                  previous: prev?.profit ?? 0,
                ),
              ),
              DataCell(
                _metricCell(
                  _fmtNum(s.grams, decimals: 0),
                  current: s.grams ?? 0,
                  previous: prev?.grams ?? 0,
                ),
              ),
              DataCell(
                _metricCell(
                  _fmtInt(s.drinks),
                  current: (s.drinks ?? 0).toDouble(),
                  previous: (prev?.drinks ?? 0).toDouble(),
                ),
              ),
              DataCell(
                _metricCell(
                  _fmtInt(s.snacks),
                  current: (s.snacks ?? 0).toDouble(),
                  previous: (prev?.snacks ?? 0).toDouble(),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _trendIcon({required double current, required double previous}) {
    if (previous == 0 && current == 0) {
      return const Icon(Icons.remove, size: 18, color: Colors.grey);
    }
    if (current > previous) {
      return const Icon(Icons.trending_up, size: 18, color: Colors.green);
    }
    if (current < previous) {
      return const Icon(Icons.trending_down, size: 18, color: Colors.red);
    }
    return const Icon(Icons.trending_flat, size: 18, color: Colors.grey);
  }

  Widget _metricCell(
    String text, {
    required double current,
    required double previous,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 6),
        _trendIcon(current: current, previous: previous),
      ],
    );
  }
}
