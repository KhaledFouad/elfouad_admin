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
import 'utils/sales_stream_provider.dart'
    show salesStreamProvider, deferredCountStreamProvider;

class SalesHistoryPage extends ConsumerWidget {
  const SalesHistoryPage({super.key});
  static const route = '/sales-history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(dateRangeProvider) ?? DateRangeController.today();
    final historyAsync = ref.watch(salesStreamProvider);
    final deferredAsync = ref.watch(deferredCountStreamProvider);

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
                _DeferredBadges(
                  totalAsync: deferredAsync,
                  rangeAsync: historyAsync,
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
            if (docs.isEmpty) {
              return const Center(child: Text('لا يوجد عمليات بيع'));
            }

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
                    'settled_at_iso': m['settled_at'] == null
                        ? null
                        : safeDate(m['settled_at']).toIso8601String(),
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
                if (buckets.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد عمليات في هذا النطاق'),
                  );
                }
                return RefreshIndicator.adaptive(
                  onRefresh: () async {
                    // إجبار إعادة الاشتراك في الستريم
                    ref.invalidate(salesStreamProvider);
                    // مهلة خفيفة عشان يرجع الاشتراك يشتغل
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
                    itemCount: buckets.length,
                    itemBuilder: (context, i) {
                      final b = buckets[i];
                      final entries =
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[
                            for (final id in b.ids)
                              if (byId[id] != null) byId[id]!,
                          ];
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
                          onEdit: (doc) => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (_) => SaleEditSheet(snap: doc),
                          ),
                          onDelete: (doc) async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('تأكيد الحذف'),
                                content: const Text(
                                  'هل تريد حذف عملية البيع؟ سيتم تعديل المخزون تلقائيًا.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              try {
                                await deleteSaleWithStockRollback(
                                  doc.reference,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تم الحذف وتمت تسوية المخزون',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('تعذر الحذف: $e')),
                                  );
                                }
                              }
                            }
                          },
                        ),
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

class _DeferredBadges extends StatelessWidget {
  const _DeferredBadges({required this.totalAsync, required this.rangeAsync});

  final AsyncValue<int> totalAsync;
  final AsyncValue<QuerySnapshot<Map<String, dynamic>>> rangeAsync;

  @override
  Widget build(BuildContext context) {
    return totalAsync.when(
      data: (total) {
        if (total <= 0) return const SizedBox.shrink();

        return rangeAsync.maybeWhen(
          data: (snap) {
            final inRangeRaw = snap.docs.where((doc) {
              final m = doc.data();
              final isDeferred = (m['is_deferred'] ?? false) == true;
              final paid = (m['paid'] ?? false) == true;
              return isDeferred && !paid;
            }).length;

            int inRange = inRangeRaw;
            if (inRange > total) inRange = total;
            if (inRange < 0) inRange = 0;

            int outsideRange = total - inRange;
            if (outsideRange < 0) outsideRange = 0;

            if (inRange == 0 && outsideRange == 0) {
              return const SizedBox.shrink();
            }

            final children = <Widget>[];
            if (inRange > 0) {
              children.add(
                _DeferredChip(
                  label: 'In range',
                  count: inRange,
                  color: Colors.teal.shade600,
                  tooltip: 'Deferred sales inside the selected range',
                ),
              );
            }
            if (outsideRange > 0) {
              if (children.isNotEmpty) {
                children.add(const SizedBox(width: 4));
              }
              children.add(
                _DeferredChip(
                  label: 'Outside',
                  count: outsideRange,
                  color: Colors.deepOrange.shade600,
                  tooltip: 'Deferred sales outside the selected range',
                ),
              );
            }

            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _DeferredChip extends StatelessWidget {
  const _DeferredChip({
    required this.label,
    required this.count,
    required this.color,
    required this.tooltip,
  });

  final String label;
  final int count;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: color,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsetsDirectional.only(end: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Text(label, style: textStyle),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: textStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
