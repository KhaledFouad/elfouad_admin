// ignore_for_file: unused_local_variable
import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/presentation/history/state/history_cubit.dart';
import 'package:elfouad_admin/presentation/history/utils/date_range_controller.dart';
import 'package:elfouad_admin/presentation/history/utils/history_compute.dart';
import 'package:elfouad_admin/presentation/history/utils/sales_history_utils.dart';
import 'package:elfouad_admin/presentation/history/widgets/day_section.dart';
import 'package:elfouad_admin/presentation/history/widgets/sale_edit_sheet.dart';
import 'package:elfouad_admin/presentation/history/widgets/sale_tile.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});
  static const route = '/sales-history';

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final range = context.read<DateRangeCubit>().state;
      context.read<HistoryCubit>().refresh(range);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = 200.0;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max - current <= threshold) {
      final range = context.read<DateRangeCubit>().state;
      context.read<HistoryCubit>().loadMore(range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.watch<DateRangeCubit>().state;

    return BlocListener<DateRangeCubit, DateTimeRange>(
      listener: (context, range) {
        context.read<HistoryCubit>().refresh(range);
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: AppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => AwesomeDrawerBar.of(context)?.toggle(),
                ),
                title: const Text(
                  AppStrings.salesHistoryTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 35,
                    color: Colors.white,
                  ),
                ),
                centerTitle: true,
                elevation: 8,
                backgroundColor: Colors.transparent,
                actions: [
                  BlocBuilder<DeferredCubit, DeferredState>(
                    builder: (context, deferredState) {
                      final n = deferredState.count;
                      if (deferredState.loadingCount ||
                          deferredState.countError != null ||
                          n == 0) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 222, 100, 100),
                          borderRadius: BorderRadius.circular(120),
                        ),
                        child: Text(
                          '$n',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: AppStrings.actionFilterByDate,
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 2),
                        lastDate: DateTime(now.year + 1),
                        initialDateRange: context.read<DateRangeCubit>().state,
                        locale: const Locale('ar'),
                        builder: (context, child) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: child!,
                        ),
                      );

                      if (picked == null) return;

                      // ???? ???? 4?4?
                      final start = DateTime(
                        picked.start.year,
                        picked.start.month,
                        picked.start.day,
                        4,
                      );
                      final end = DateTime(
                        picked.end.year,
                        picked.end.month,
                        picked.end.day,
                        4,
                      ).add(const Duration(days: 1));

                      if (!context.mounted) return;

                      // Action Sheet ??? ???????? (?? ??? ???????)
                      await showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (ctx) {
                          return Directionality(
                            textDirection: TextDirection.rtl,
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    title:
                                        const Text(AppStrings.actionApplyFilter),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      context.read<DateRangeCubit>().setRange(
                                            DateTimeRange(
                                              start: start,
                                              end: end,
                                            ),
                                          );
                                    },
                                  ),
                                  ListTile(
                                    leading:
                                        const Icon(Icons.file_download),
                                    title:
                                        const Text(AppStrings.actionExportExcel),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      exportSalesExcelFromFilter(
                                        context,
                                        DateTimeRange(
                                          start: start,
                                          end: end,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.filter_alt, color: Colors.white),
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
              ),
            ),
          ),
          body: BlocBuilder<HistoryCubit, HistoryState>(
            builder: (context, historyState) {
              if (historyState.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (historyState.error != null) {
                return Center(
                  child: Text(
                    AppStrings.historyLoadError(
                      historyState.error ?? 'unknown',
                    ),
                  ),
                );
              }

              final docsList = historyState.docs
                  .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

              // ???? ?????? ????? ????????? 
              final rows = docsList
                  .map((d) {
                    final m = d.data();
                    final totals = saleTotalsWithFallback(m);
                    DateTime safeDate(dynamic v) {
                      if (v is Timestamp) return v.toDate();
                      if (v is DateTime) return v;
                      if (v is num) {
                        final raw = v.toInt();
                        final ms = raw < 10000000000 ? raw * 1000 : raw;
                        return DateTime.fromMillisecondsSinceEpoch(ms);
                      }
                      return DateTime.tryParse('${v ?? ''}') ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                    }

                    return {
                      'id': d.id,
                      'type': m['type'],
                      'is_deferred': (m['is_deferred'] ?? false) == true,
                      'paid': (m['paid'] ?? false) == true,
                      'created_at_iso': safeDate(
                        m['created_at'],
                      ).toIso8601String(),
                      'original_created_at_iso':
                          m['original_created_at'] == null
                              ? null
                              : safeDate(m['original_created_at'])
                                  .toIso8601String(),
                      'settled_at_iso': m['settled_at'] == null
                          ? null
                          : safeDate(m['settled_at']).toIso8601String(),
                      'updated_at_iso': m['updated_at'] == null
                          ? null
                          : safeDate(m['updated_at']).toIso8601String(),
                      'total_price': totals.price,
                      'total_cost': totals.cost,
                      'profit_total': totals.profit,
                      'quantity': m['quantity'],
                      'grams': m['grams'],
                      'total_grams': m['total_grams'],
                    };
                  })
                  .toList(growable: false);

              // Map ???? ?? id  doc ????? ???? ?????????? ??? ??????
              final byId = {for (final d in docsList) d.id: d};

              // ???? ??????? ?? Isolate
              return FutureBuilder<List<DayBucket>>(
                future: compute(buildBuckets, {
                  'rows': rows,
                  'start': r.start.toIso8601String(),
                  'end': r.end.toIso8601String(),
                }),
                builder: (context, aggSnap) {
                  if (!aggSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final buckets = aggSnap.data!;
                  final daySections = <_BucketViewModel>[];
                  for (final bucket in buckets) {
                    final entries =
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    for (final id in bucket.ids) {
                      final doc = byId[id];
                      if (doc == null) continue;
                      final data = doc.data();
                      final isDeferred =
                          (data['is_deferred'] ?? false) == true;
                      final paid = (data['paid'] ?? false) == true;
                      if (isDeferred && !paid) continue;
                      entries.add(doc);
                    }
                    final hasData = entries.isNotEmpty || bucket.opCount > 0;
                    if (hasData) {
                      daySections.add(
                        _BucketViewModel(bucket: bucket, entries: entries),
                      );
                    }
                  }
                  final hasDaySections = daySections.isNotEmpty;
                  final baseCount = hasDaySections ? daySections.length : 1;
                  final totalItems =
                      baseCount + 1 + (historyState.loadingMore ? 1 : 0);

                  void openEdit(DocumentSnapshot<Map<String, dynamic>> doc) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => SaleEditSheet(snap: doc),
                    );
                  }

                  Future<void> deleteDoc(
                    DocumentSnapshot<Map<String, dynamic>> doc,
                  ) async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text(AppStrings.deleteSaleTitle),
                        content: const Text(
                          AppStrings.deleteSaleConfirm,
                          textAlign: TextAlign.center,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(AppStrings.actionCancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(AppStrings.actionDelete),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      try {
                        await deleteSaleWithStockRollback(doc.reference);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(AppStrings.saleDeletedRollback),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppStrings.saleDeleteFailed(e)),
                            ),
                          );
                        }
                      }
                    }
                  }

                  return RefreshIndicator.adaptive(
                    onRefresh: () async {
                      await context.read<HistoryCubit>().refresh(r);
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      cacheExtent: 800,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: totalItems,
                      itemBuilder: (context, i) {
                        if (!hasDaySections) {
                          if (i == 0) {
                            return const _HistoryEmptyPlaceholder();
                          }
                          if (i == 1) {
                            return BlocBuilder<DeferredCubit, DeferredState>(
                              builder: (context, deferredState) {
                                return _DeferredOutstandingPanel(
                                  deferredState: deferredState,
                                  onEdit: openEdit,
                                  onDelete: deleteDoc,
                                );
                              },
                            );
                          }
                          return const _LoadMoreIndicator();
                        }

                        if (i < daySections.length) {
                          final vm = daySections[i];
                          final b = vm.bucket;
                          final entries = vm.entries;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DaySection(
                              day: b.dayKey,
                              entries: entries,
                              sumPrice: b.sumPrice,
                              sumCost: b.sumCost,
                              sumProfit: b.sumProfit,
                              cups: b.cups,
                              grams: b.grams,
                              extrasPieces: b.extrasPieces,
                              saleCount: b.opCount,
                              onEdit: openEdit,
                              onDelete: deleteDoc,
                            ),
                          );
                        }

                        if (i == daySections.length) {
                          return BlocBuilder<DeferredCubit, DeferredState>(
                            builder: (context, deferredState) {
                              return _DeferredOutstandingPanel(
                                deferredState: deferredState,
                                onEdit: openEdit,
                                onDelete: deleteDoc,
                              );
                            },
                          );
                        }

                        return historyState.loadingMore
                            ? const _LoadMoreIndicator()
                            : const SizedBox.shrink();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BucketViewModel {
  const _BucketViewModel({required this.bucket, required this.entries});

  final DayBucket bucket;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> entries;
}

class _HistoryEmptyPlaceholder extends StatelessWidget {
  const _HistoryEmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          AppStrings.noSalesInRange,
          style: const TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DeferredOutstandingPanel extends StatelessWidget {
  const _DeferredOutstandingPanel({
    required this.deferredState,
    required this.onEdit,
    required this.onDelete,
  });

  final DeferredState deferredState;
  final void Function(DocumentSnapshot<Map<String, dynamic>> doc) onEdit;
  final void Function(DocumentSnapshot<Map<String, dynamic>> doc) onDelete;

  @override
  Widget build(BuildContext context) {
    if (deferredState.loadingUnpaid) {
      return const SizedBox.shrink();
    }
    if (deferredState.unpaidError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              AppStrings.deferredLoadError(
                deferredState.unpaidError ?? 'unknown',
              ),
            ),
          ),
        ),
      );
    }

    final docs = deferredState.unpaid
        .where((d) => (d.data()['paid'] ?? false) == false)
        .toList();

    if (docs.isEmpty) {
      return const SizedBox.shrink();
    }

    DateTime createdAtOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data();
      final ts = data['created_at'];
      if (ts is Timestamp) return ts.toDate();
      if (ts is DateTime) return ts;
      if (ts is num) {
        final raw = ts.toInt();
        final ms = raw < 10000000000 ? raw * 1000 : raw;
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      return DateTime.tryParse('${ts ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    docs.sort((a, b) => createdAtOf(a).compareTo(createdAtOf(b)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 3,
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.deepOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.deferredPending(docs.length),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    AppStrings.oldestFirst,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                AppStrings.deferredNoteHint,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, index) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final createdAt = createdAtOf(doc).toLocal();
                  final createdLabel = fmtDateTime(createdAt);
                  final note =
                      ((data['note'] ?? data['notes'] ?? '') as Object)
                          .toString()
                          .trim();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            createdLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (note.isNotEmpty) ...[
                            const Spacer(),
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: Colors.black45,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      SaleTile(
                        key: ValueKey('deferred-${doc.id}'),
                        doc: doc,
                        onEdit: () => onEdit(doc),
                        onDelete: () => onDelete(doc),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
