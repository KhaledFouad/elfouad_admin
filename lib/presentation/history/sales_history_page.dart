// ignore_for_file: unused_local_variable
import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/presentation/history/utils/date_range_controller.dart'
    show dateRangeProvider, DateRangeController;
import 'package:elfouad_admin/presentation/history/utils/sales_history_utils.dart';
import 'package:elfouad_admin/presentation/history/utils/sales_stream_provider.dart';
import 'package:elfouad_admin/presentation/history/widgets/day_section.dart';
import 'package:elfouad_admin/presentation/history/widgets/sale_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elfouad_admin/presentation/history/utils/sales_stream_provider.dart'
    show
        salesStreamProvider,
        deferredCountStreamProvider,
        unpaidDeferredStreamProvider;

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});
  static const route = '/sales-history';

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  double _numD(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;

  bool _isUnpaidDeferredMap(Map<String, dynamic> m) =>
      (m['is_deferred'] ?? false) == true && (m['paid'] ?? false) == false;

  /// إجمالي المبيعات يوميًا بدون الأجل غير المدفوع
  double _sumPriceExcludingDeferred(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
  ) {
    double s = 0;
    for (final e in es) {
      final m = e.data();
      if (_isUnpaidDeferredMap(m)) continue;
      s += _numD(m['total_price']);
    }
    return s;
  }

  /// إجمالي التكلفة لغير الأجل غير المدفوع
  double _sumCostExcludingDeferred(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> es,
  ) {
    double s = 0;
    for (final e in es) {
      final m = e.data();
      if (_isUnpaidDeferredMap(m)) continue;
      s += _numD(m['total_cost']);
    }
    return s;
  }

  /// مفتاح يوم التشغيل للدوكيومنت
  String _docDayKey(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final ts =
        (m['created_at'] as Timestamp?)?.toDate() ??
        DateTime.tryParse(m['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return dayKeyFromUtc(ts);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final init = ref.read(dateRangeProvider) ?? DateRangeController.today();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: init,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );

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
      ref
          .read(dateRangeProvider.notifier)
          .setRange(DateTimeRange(start: start, end: end));
    }
  }

  void _openEditSheet(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final before = Map<String, dynamic>.from(doc.data() ?? {});

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SaleEditSheet(snap: doc),
    );

    // بعد ما يقفل الشيت، نقرأ الدوك تاني (على أمل إنه اتعدّل)
    final afterSnap = await doc.reference.get();
    final after = Map<String, dynamic>.from(afterSnap.data() ?? {});

    try {
      await applyStockDiffForEdit(before: before, after: after);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر مزامنة المخزون بعد التعديل: $e')),
      );
    }
  }

  Future<void> _deleteSale(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف عملية البيع هذه؟ لا يمكن التراجع.'),
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
    if (ok != true) return;

    try {
      await restoreStockOnSaleDelete(
        doc.reference,
      ); // ✅ يرجّع المخزون ويعمل delete داخل نفس الـTX
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف عملية البيع واسترجاع المخزون')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذّر الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deferredCount = ref.watch(deferredCountStreamProvider);
    final unpaidDeferred = ref.watch(unpaidDeferredStreamProvider);

    final nowKey = dayKeyFromUtc(DateTime.now().toUtc()); // يوم التشغيل الحالي

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
                Row(
                  children: [
                    deferredCount.when(
                      data: (n) => n == 0
                          ? const SizedBox.shrink()
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
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
                      onPressed: _pickRange,
                      icon: const Icon(Icons.filter_alt, color: Colors.white),
                    ),
                  ],
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
                // 1) سيكشن "الأجل غير المدفوع" لليوم الذي عدى فقط + إظهار التاريخ
                final Widget deferredSection = unpaidDeferred.when(
                  data: (ds) {
                    final entries = ds.docs
                        .where((d) => _docDayKey(d).compareTo(nowKey) < 0)
                        .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
                        .toList();

                    if (entries.isEmpty) return const SizedBox.shrink();

                    final dateKeys =
                        entries.map((d) => _docDayKey(d)).toSet().toList()
                          ..sort();
                    final datesLabel = dateKeys.join('، ');
                    final sectionTitle =
                        'عمليات الأجل (غير مدفوعة) - $datesLabel';

                    // في هذا السيكشن الربح يُعتبر 0 لأنه مستبعد
                    final sumPrice = sumField(entries, 'total_price');
                    final cups = sumDrinkCups(entries);
                    final grams = sumBeansGrams(entries);

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: DaySection(
                        day: sectionTitle,
                        entries: entries,
                        sumPrice: sumPrice,
                        sumCost: sumField(entries, 'total_cost'),
                        sumProfit: 0, // مستبعد من الربح
                        cups: cups,
                        grams: grams,
                        onEdit: _openEditSheet,
                        onDelete: _deleteSale,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );

                // 2) باقي الأيام — نمنع تكرار الأجل القديم، ونبقي أجل "اليوم الحالي" داخل يومه
                final allDocs = snap.docs;
                if (allDocs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      deferredSection,
                      const SizedBox(height: 12),
                      const Center(
                        child: Text('لا يوجد عمليات بيع ضمن المدى المختار'),
                      ),
                    ],
                  );
                }

                final filtered = allDocs.where((d) {
                  final m = d.data();
                  if (!_isUnpaidDeferredMap(m)) return true;
                  final k = _docDayKey(d);
                  return k == nowKey; // أجل اليوم الحالي فقط يظهر داخل يومه
                }).toList();

                // group by operational day (shift -4h)
                final byDay = groupByOperationalDay(filtered);
                final dayKeys = byDay.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: 1 + dayKeys.length, // +1 للسيكشن المثبّت
                  itemBuilder: (context, i) {
                    if (i == 0) return deferredSection;

                    final day = dayKeys[i - 1];
                    final entries = byDay[day]!;

                    // المبيعات اليومية تستبعد الأجل غير المدفوع
                    final salesNet = _sumPriceExcludingDeferred(entries);
                    // الربح اليومي = (سعر غير الأجل) - (تكلفة غير الأجل)
                    final costNet = _sumCostExcludingDeferred(entries);
                    final profitNet = salesNet - costNet;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DaySection(
                        day: day,
                        entries: entries,
                        sumPrice: salesNet,
                        sumCost: sumField(entries, 'total_cost'), // للعرض فقط
                        sumProfit: profitNet,
                        cups: sumDrinkCups(entries),
                        grams: sumBeansGrams(entries),
                        onEdit: _openEditSheet,
                        onDelete: _deleteSale,
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
