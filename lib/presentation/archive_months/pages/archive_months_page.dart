import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/History/widgets/summary_pill.dart';

import '../bloc/archive_months_cubit.dart';
import '../bloc/archive_months_state.dart';
import '../models/archive_month.dart';
import '../widgets/archive_summary_table.dart';
import '../widgets/archive_trend_charts.dart';
import 'archive_month_detail_page.dart';

class ArchiveMonthsPage extends StatelessWidget {
  const ArchiveMonthsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ArchiveMonthsCubit()..load(),
      child: const _ArchiveMonthsView(),
    );
  }
}

class _ArchiveMonthsView extends StatelessWidget {
  const _ArchiveMonthsView();

  String _formatUpdated(DateTime? value) {
    if (value == null) return '';
    return intl.DateFormat('yyyy-MM-dd HH:mm', 'ar').format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const _ArchiveAppBar(),
        body: BlocBuilder<ArchiveMonthsCubit, ArchiveMonthsState>(
          builder: (context, state) {
            if (state.loading && state.months.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => context.read<ArchiveMonthsCubit>().refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                children: [
                  if (state.fromCache)
                    _CacheNotice(updatedAt: _formatUpdated(state.lastUpdated)),

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
                          if (state.error != null && state.months.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                AppStrings.loadFailed(
                                  AppStrings.archiveSummaryTitle,
                                  state.error ?? 'unknown',
                                ),
                              ),
                            )
                          else
                            ArchiveSummaryTable(
                              months: state.months,
                              onSelect: (month) => _openMonth(context, month),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (state.months.isNotEmpty) ...[
                    ArchiveTrendsCard(months: state.months),
                    const SizedBox(height: 16),
                  ],

                  if (state.months.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('لا توجد بيانات للشهر بعد'),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: state.months
                          .map(
                            (m) => _ArchiveMonthCard(
                              month: m,
                              onTap: () => _openMonth(context, m),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openMonth(BuildContext context, ArchiveMonth month) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchiveMonthDetailPage(month: month),
      ),
    );
  }
}

class _ArchiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ArchiveAppBar();

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
        title: const Text(
          AppStrings.archiveTitle,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
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

class _CacheNotice extends StatelessWidget {
  const _CacheNotice({required this.updatedAt});

  final String updatedAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.brown.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.offline_pin, color: Colors.brown.shade600, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                updatedAt.isEmpty
                    ? AppStrings.archiveCachedNotice
                    : '${AppStrings.archiveCachedNotice} • $updatedAt',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveMonthCard extends StatelessWidget {
  const _ArchiveMonthCard({required this.month, required this.onTap});

  final ArchiveMonth month;
  final VoidCallback onTap;

  String _label(BuildContext context) {
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
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width >= 900
        ? (width - 48) / 3
        : (width >= 600 ? (width - 36) / 2 : width);

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF5D4037)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _label(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_left, color: Colors.brown),
                  ],
                ),
                const SizedBox(height: 10),
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
                      icon: Icons.scale,
                      label: AppStrings.gramsCoffeeLabel,
                      value: _fmtNum(summary.grams, decimals: 0),
                    ),
                    SummaryPill(
                      icon: Icons.local_cafe,
                      label: AppStrings.cupsLabelShort,
                      value: _fmtInt(summary.drinks),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text(AppStrings.archiveOpenDetails),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
