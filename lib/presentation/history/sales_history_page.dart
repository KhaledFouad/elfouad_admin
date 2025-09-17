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

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});
  static const route = '/sales-history';

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
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

  void _openEditSheet(DocumentSnapshot<Map<String, dynamic>> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SaleEditSheet(snap: doc),
    );
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
    await doc.reference.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حذف عملية البيع')));
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(dateRangeProvider);
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
                IconButton(
                  tooltip: 'تصفية بالتاريخ',
                  onPressed: _pickRange,
                  icon: const Icon(Icons.filter_alt, color: Colors.white),
                ),
                // if (r != null)
                //   IconButton(
                //     tooltip: 'مسح الفلتر',
                //     onPressed: () =>
                //         ref.read(dateRangeProvider.notifier).clear(),
                //     icon: const Icon(Icons.clear),
                //   ),
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
                final docs = snap.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('لا يوجد عمليات بيع'));
                }

                // group by operational day (shift -4h)
                final byDay = groupByOperationalDay(docs);

                final dayKeys = byDay.keys.toList()
                  ..sort((a, b) => b.compareTo(a));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: dayKeys.length,
                  itemBuilder: (context, i) {
                    final day = dayKeys[i];
                    final entries = byDay[day]!;

                    final sumPrice = sumField(entries, 'total_price');
                    final sumCost = sumField(entries, 'total_cost');
                    final sumProfit = sumPrice - sumCost;
                    final cups = sumDrinkCups(entries);
                    final grams = sumBeansGrams(entries);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DaySection(
                        day: day,
                        entries: entries,
                        sumPrice: sumPrice,
                        sumCost: sumCost,
                        sumProfit: sumProfit,
                        cups: cups,
                        grams: grams,
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
