import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:elfouad_admin/core/utils/app_strings.dart';

import '../models/stats_models.dart';
import '../utils/op_day.dart';

part 'stats_data_provider/stats_models_helpers.dart';
part 'stats_data_provider/query_builders.dart';
part 'stats_data_provider/kpi_calculator.dart';

/// Public entry points for stats data retrieval and aggregation.
DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);

DateTime _nextMonth(DateTime d) => d.month == 12
    ? DateTime(d.year + 1, 1, 1)
    : DateTime(d.year, d.month + 1, 1);

Future<List<Map<String, dynamic>>> fetchSalesRawForRange({
  required DateTime startLocal,
  required DateTime endLocal,
  bool cacheFirst = false,
}) async {
  final start = _monthStart(startLocal);
  final end = _monthStart(endLocal);
  final combined = <String, Map<String, dynamic>>{};

  var cursor = start;
  while (!cursor.isAfter(end)) {
    final raw = await _fetchSalesRawForMonth(cursor, cacheFirst: cacheFirst);
    for (final entry in raw) {
      final id = (entry['id'] ?? entry['sale_id'] ?? '').toString();
      if (id.isNotEmpty) {
        combined[id] = entry;
      } else {
        combined['${cursor.millisecondsSinceEpoch}-${combined.length}'] = entry;
      }
    }
    cursor = _nextMonth(cursor);
  }

  return combined.values.toList();
}

Future<List<Map<String, dynamic>>> fetchSalesRawForMonth(
  DateTime month, {
  bool cacheFirst = false,
}) {
  return _fetchSalesRawForMonth(month, cacheFirst: cacheFirst);
}

List<Map<String, dynamic>> prepareStatsData(List<Map<String, dynamic>> data) =>
    _prepareStatsData(data);

List<Map<String, dynamic>> filterStatsSales(
  List<Map<String, dynamic>> rawMonth, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _filterStatsSales(rawMonth, startUtc: startUtc, endUtc: endUtc);

Future<List<Map<String, dynamic>>> fetchStatsExpenses({
  required DateTime startUtc,
  required DateTime endUtc,
  bool cacheFirst = false,
}) => _fetchStatsExpenses(
  startUtc: startUtc,
  endUtc: endUtc,
  cacheFirst: cacheFirst,
);

List<Map<String, dynamic>> filterStatsExpenses(
  List<Map<String, dynamic>> rawMonth, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _filterStatsExpenses(rawMonth, startUtc: startUtc, endUtc: endUtc);

Kpis buildKpis(
  List<Map<String, dynamic>> data,
  List<Map<String, dynamic>> expensesList, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _buildKpis(data, expensesList, startUtc: startUtc, endUtc: endUtc);

List<GroupRow> buildExtrasRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _buildExtrasRows(data, startUtc: startUtc, endUtc: endUtc);

List<GroupRow> buildDrinksRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _buildDrinksRows(data, startUtc: startUtc, endUtc: endUtc);

List<GroupRow> buildBeansRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _buildBeansRows(data, startUtc: startUtc, endUtc: endUtc);

List<GroupRow> buildTurkishRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _buildTurkishRows(data, startUtc: startUtc, endUtc: endUtc);

StatsHighlights buildHighlights(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _buildHighlights(data, startUtc: startUtc, endUtc: endUtc);

TrendsBundle buildTrends(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) => _buildTrends(data, startUtc: startUtc, endUtc: endUtc);
