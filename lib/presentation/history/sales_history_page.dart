// ignore_for_file: unused_local_variable
import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/history/utils/history_compute.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'utils/date_range_controller.dart'
    show dateRangeProvider, DateRangeController;
import 'utils/sales_history_utils.dart';
import 'utils/sales_stream_provider.dart';
import 'widgets/day_section.dart';
import 'widgets/sale_edit_sheet.dart';
import 'widgets/sale_tile.dart';
import 'utils/sales_stream_provider.dart'
    show
        salesStreamProvider,
        deferredCountStreamProvider,
        unpaidDeferredStreamProvider;

class SalesHistoryPage extends ConsumerWidget {
  const SalesHistoryPage({super.key});
  static const route = '/sales-history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(dateRangeProvider) ?? DateRangeController.today();
    final historyAsync = ref.watch(salesStreamProvider);
    final deferredAsync = ref.watch(deferredCountStreamProvider);
    final unpaidDeferredAsync = ref.watch(unpaidDeferredStreamProvider);

    return Directionality(
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
                'سجلّ المبيعات',
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
                deferredAsync.when(
                  data: (n) => n == 0
                      ? const SizedBox.shrink()
                      : Container(
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
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, stackTrace) => const SizedBox.shrink(),
                ),
                IconButton(
                  tooltip: 'تصفية بالتاريخ',
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 2),
                      lastDate: DateTime(now.year + 1),
                      initialDateRange:
                          ref.read(dateRangeProvider) ??
                          DateRangeController.today(),
                      locale: const Locale('ar'),
                      builder: (context, child) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: child!,
                      ),
                    );

                    if (picked == null) return;

                    // نحول لمدى 4ص→4ص
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

                    // Action Sheet بعد الاختيار (من جوه التصفية)
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
                                  title: const Text('تطبيق الفلتر'),
                                  onTap: () {
                                    // يقفل الشيت تلقائيًا
                                    Navigator.pop(ctx);
                                    // يحدّث الرينج
                                    ref
                                        .read(dateRangeProvider.notifier)
                                        .setRange(
                                          DateTimeRange(start: start, end: end),
                                        );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.file_download),
                                  title: const Text('تصدير Excel لهذا النطاق'),
                                  onTap: () {
                                    Navigator.pop(ctx); // يقفل الشيت تلقائيًا
                                    exportSalesExcelFromFilter(
                                      context,
                                      DateTimeRange(start: start, end: end),
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
        body: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('خطأ في تحميل السجل: $e')),
          data: (snap) {
            // sales_history_page.dart (داخل data: (snap) { ... })
            final docs = snap.docs
                .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

            // حضّر بيانات خفيفة للإيزوليت
            final rows = docs
                .map((d) {
                  final m = d.data();
                  DateTime safeDate(dynamic v) {
                    if (v is Timestamp) return v.toDate();
                    if (v is DateTime) return v;
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
                    'original_created_at_iso': m['original_created_at'] == null
                        ? null
                        : safeDate(m['original_created_at']).toIso8601String(),
                    'settled_at_iso': m['settled_at'] == null
                        ? null
                        : safeDate(m['settled_at']).toIso8601String(),
                    'updated_at_iso': m['updated_at'] == null
                        ? null
                        : safeDate(m['updated_at']).toIso8601String(),
                    'total_price': m['total_price'],
                    'total_cost': m['total_cost'],
                    'profit_total': m['profit_total'],
                    'quantity': m['quantity'],
                    'grams': m['grams'],
                    'total_grams': m['total_grams'],
                  };
                })
                .toList(growable: false);

            // Map سريع من id → doc علشان نجيب الدوكيومنت وقت البناء
            final byId = {for (final d in docs) d.id: d};

            // شغّل التجميع في Isolate
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
                      final isDeferred = (data['is_deferred'] ?? false) == true;
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
                final totalItems =
                    (hasDaySections ? daySections.length : 1) + 1;

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
                      title: const Text('حذف عملية البيع؟'),
                      content: const Text(
                        'سيتم حذف هذه العملية وإرجاع أي تأثير على المخزون. هل تريد المتابعة؟',
                        textAlign: TextAlign.center,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('حذف'),
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
                            content: Text('تم حذف العملية وإرجاع المخزون.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر حذف العملية: $e')),
                        );
                      }
                    }
                  }
                }

                return RefreshIndicator.adaptive(
                  onRefresh: () async {
                    ref.invalidate(salesStreamProvider);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 300),
                    );
                  },
                  child: ListView.builder(
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
                        return _DeferredOutstandingPanel(
                          unpaidAsync: unpaidDeferredAsync,
                          onEdit: openEdit,
                          onDelete: deleteDoc,
                        );
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

                      return _DeferredOutstandingPanel(
                        unpaidAsync: unpaidDeferredAsync,
                        onEdit: openEdit,
                        onDelete: deleteDoc,
                      );
                    },
                  ),
                );
              },
            );
          },
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
          'لا توجد عمليات في هذه الفترة.',
          style: const TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DeferredOutstandingPanel extends StatelessWidget {
  const _DeferredOutstandingPanel({
    required this.unpaidAsync,
    required this.onEdit,
    required this.onDelete,
  });

  final AsyncValue<QuerySnapshot<Map<String, dynamic>>> unpaidAsync;
  final void Function(DocumentSnapshot<Map<String, dynamic>> doc) onEdit;
  final void Function(DocumentSnapshot<Map<String, dynamic>> doc) onDelete;

  @override
  Widget build(BuildContext context) {
    return unpaidAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, stackTrace) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('تعذر تحميل الديون المؤجلة: $e'),
          ),
        ),
      ),
      data: (snap) {
        final docs = snap.docs
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
                        'Deferred pending (${docs.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Oldest first',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Original date & time shown. Use edit to add notes.',
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
      },
    );
  }
}
