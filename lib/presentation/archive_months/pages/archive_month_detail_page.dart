import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/History/widgets/summary_pill.dart';
import 'package:elfouad_admin/presentation/stats/widgets/beans_by_name_table.dart';
import 'package:elfouad_admin/presentation/stats/widgets/turkish_coffee_table.dart';

import '../models/archive_month.dart';

class ArchiveMonthDetailPage extends StatelessWidget {
  const ArchiveMonthDetailPage({super.key, required this.month});

  final ArchiveMonth month;

  String _label() {
    final date = month.monthDate;
    if (date == null) return month.rawLabel;
    return intl.DateFormat('MMMM yyyy', 'ar').format(date);
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
    final summary = month.summary;
    final turkishRows = _parseTurkishRows(month.data['turkish_rows']);
    final beansRows = _parseBeanRows(month.data['beans_rows']);
    final totalTurkishCups =
        turkishRows.fold<int>(0, (s, r) => s + r.cups);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _ArchiveMonthAppBar(title: _label()),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        AppStrings.archiveSummaryTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SummaryPill(
                          icon: Icons.attach_money,
                          label: AppStrings.salesLabel,
                          value: _fmtNum(summary.sales),
                        ),
                        SummaryPill(
                          icon: Icons.trending_up,
                          label: AppStrings.profitLabel,
                          value: _fmtNum(summary.profit),
                        ),
                        SummaryPill(
                          icon: Icons.factory,
                          label: AppStrings.costLabel,
                          value: _fmtNum(summary.cost),
                        ),
                        SummaryPill(
                          icon: Icons.scale,
                          label: AppStrings.gramsCoffeeLabel,
                          value: _fmtNum(summary.grams, decimals: 0),
                        ),
                        SummaryPill(
                          icon: Icons.local_cafe,
                          label: AppStrings.cupsLabelShort,
                          value: _fmtInt(summary.drinks),
                        ),
                        SummaryPill(
                          icon: Icons.cookie_rounded,
                          label: AppStrings.snacksLabel,
                          value: _fmtInt(summary.snacks),
                        ),
                        SummaryPill(
                          icon: Icons.account_balance_wallet,
                          label: AppStrings.expensesTitle,
                          value: _fmtNum(summary.expenses),
                        ),
                      ],
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
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        AppStrings.turkishCoffeeTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (turkishRows.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          AppStrings.turkishCoffeeTotalCups(totalTurkishCups),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    TurkishCoffeeTable(rows: turkishRows),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        AppStrings.beansByNameTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    BeansByNameTable(rows: beansRows),
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

class _ArchiveMonthAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ArchiveMonthAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: AppStrings.tooltipBack,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 8,
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
    );
  }
}


List<TurkishRow> _parseTurkishRows(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((entry) {
    final map = _asStringMap(entry);
    if (map.isEmpty) return null;
    final name = (map['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final cups = _intFrom(map['cups']);
    final plain = _intFrom(map['plainCups'] ?? map['plain_cups']);
    final spiced = _intFrom(map['spicedCups'] ?? map['spiced_cups']);
    final totalCups = cups > 0 ? cups : (plain + spiced);
    return TurkishRow(
      name: name,
      cups: totalCups,
      plainCups: plain,
      spicedCups: spiced,
      sales: _numFrom(map['sales']),
      cost: _numFrom(map['cost']),
    );
  }).whereType<TurkishRow>().toList();
}

List<BeanRow> _parseBeanRows(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((entry) {
    final map = _asStringMap(entry);
    if (map.isEmpty) return null;
    final name = (map['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    return BeanRow(
      name: name,
      grams: _numFrom(map['grams']),
      plainGrams: _numFrom(map['plainGrams'] ?? map['plain_grams']),
      spicedGrams: _numFrom(map['spicedGrams'] ?? map['spiced_grams']),
      sales: _numFrom(map['sales']),
      cost: _numFrom(map['cost']),
    );
  }).whereType<BeanRow>().toList();
}

Map<String, dynamic> _asStringMap(dynamic entry) {
  if (entry is Map<String, dynamic>) return entry;
  if (entry is Map) {
    return entry.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  return {};
}

double _numFrom(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final str = value.toString().trim();
  if (str.isEmpty) return 0;
  return double.tryParse(str) ?? 0;
}

int _intFrom(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.round();
  final str = value.toString().trim();
  if (str.isEmpty) return 0;
  return int.tryParse(str) ?? 0;
}
