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
                ref
                    .watch(deferredCountStreamProvider)
                    .when(
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
                      error: (_, __) => const SizedBox.shrink(),
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
        body: ref
            .watch(salesStreamProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('خطأ في تحميل السجل: $e')),
              data: (snap) {
                // sales_history_page.dart (داخل data: (snap) { ... })
                final docs = snap.docs
                    .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                if (docs.isEmpty)
                  return const Center(child: Text('لا يوجد عمليات بيع'));

                // حضّر بيانات خفيفة للإيزوليت
                final rows = docs
                    .map((d) {
                      final m = d.data();
                      DateTime _dt(dynamic v) {
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
                        'created_at_iso': _dt(
                          m['created_at'],
                        ).toIso8601String(),
                        'settled_at_iso': m['settled_at'] == null
                            ? null
                            : _dt(m['settled_at']).toIso8601String(),
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
                              cups: sumDrinkCups(entries),
                              grams: sumBeansGrams(entries),
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'تم الحذف وتمت تسوية المخزون',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('تعذر الحذف: $e'),
                                        ),
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

Future<void> _forceRefresh(WidgetRef ref) async {
  // خفّف: متعملش q.get(...).
  ref.invalidate(salesStreamProvider);
  ref.invalidate(deferredCountStreamProvider);
  await Future<void>.delayed(const Duration(milliseconds: 150));
}
