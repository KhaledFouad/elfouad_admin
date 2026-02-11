import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/archive/bloc/archive_trash_cubit.dart';
import 'package:elfouad_admin/presentation/archive/bloc/archive_trash_state.dart';
import 'package:elfouad_admin/presentation/archive/models/archive_entry.dart';
import 'package:elfouad_admin/presentation/archive/utils/archive_utils.dart';
import 'package:elfouad_admin/presentation/archive/widgets/archive_entry_card.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:elfouad_admin/presentation/expenses/utils/expenses_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  static const route = '/archive-trash';

  @override
  Widget build(BuildContext context) {
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final contentMaxWidth = breakpoints.largerThan(TABLET)
        ? 1100.0
        : double.infinity;
    final horizontalPadding = isPhone ? 10.0 : 16.0;

    return BlocProvider(
      create: (_) => ArchiveTrashCubit(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(90),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: BlocBuilder<ArchiveTrashCubit, ArchiveTrashState>(
                buildWhen: (prev, curr) => prev.range != curr.range,
                builder: (context, state) {
                  return AppBar(
                    automaticallyImplyLeading: false,
                    leading: IconButton(
                      icon: const Icon(Icons.home_rounded, color: Colors.white),
                      onPressed: () =>
                          context.read<NavCubit>().setTab(AppTab.home),
                      tooltip: AppStrings.tabHome,
                    ),
                    centerTitle: true,
                    title: const Text(
                      AppStrings.recycleBinTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        color: Colors.white,
                      ),
                    ),
                    actions: [
                      IconButton(
                        tooltip: AppStrings.actionFilterByDate,
                        onPressed: () => _pickRange(context, state.range),
                        icon: const Icon(Icons.filter_alt_rounded),
                        color: Colors.white,
                      ),
                      if (!_sameRange(
                        state.range,
                        todayOperationalRangeLocal(),
                      ))
                        IconButton(
                          tooltip: AppStrings.actionOperationalDay,
                          onPressed: () {
                            context.read<ArchiveTrashCubit>().setRange(
                              todayOperationalRangeLocal(),
                            );
                          },
                          icon: const Icon(Icons.restart_alt),
                          color: Colors.white,
                        ),
                    ],
                    flexibleSpace: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5D4037), Color(0xFF795548)],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: const [
                    SizedBox(height: 10),
                    _ArchiveFilters(),
                    SizedBox(height: 10),
                    Expanded(child: _ArchiveList()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context, DateTimeRange current) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: current,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (!context.mounted) return;
    if (picked != null) {
      final start = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
        4,
      );
      final endBase = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        4,
      );
      final end = endBase.add(const Duration(days: 1));
      context.read<ArchiveTrashCubit>().setRange(
        DateTimeRange(start: start, end: end),
      );
    }
  }

  bool _sameRange(DateTimeRange a, DateTimeRange b) {
    return a.start == b.start && a.end == b.end;
  }
}

class _ArchiveFilters extends StatelessWidget {
  const _ArchiveFilters();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArchiveTrashCubit, ArchiveTrashState>(
      buildWhen: (prev, curr) => prev.filter != curr.filter,
      builder: (context, state) {
        final filters = ArchiveFilter.values;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in filters)
              FilterChip(
                label: Text(filterLabel(filter)),
                selected: state.filter == filter,
                onSelected: (_) =>
                    context.read<ArchiveTrashCubit>().setFilter(filter),
              ),
          ],
        );
      },
    );
  }
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArchiveTrashCubit, ArchiveTrashState>(
      buildWhen: (prev, curr) =>
          prev.loading != curr.loading ||
          prev.error != curr.error ||
          prev.entries != curr.entries ||
          prev.filter != curr.filter ||
          prev.restoringIds != curr.restoringIds,
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null) {
          return Center(child: Text(state.error.toString()));
        }

        final entries = filterEntries(state.entries, state.filter);
        if (entries.isEmpty) {
          return const Center(child: Text(AppStrings.recycleBinEmpty));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isRestoring = state.isRestoring(entry.id);
            return ArchiveEntryCard(
              entry: entry,
              isRestoring: isRestoring,
              onRestore: () => _restoreEntry(context, entry),
            );
          },
        );
      },
    );
  }

  Future<void> _restoreEntry(BuildContext context, ArchiveEntry entry) async {
    try {
      await context.read<ArchiveTrashCubit>().restoreEntry(entry);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.restoreSuccess)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.restoreFailed}: $e')),
      );
    }
  }
}
