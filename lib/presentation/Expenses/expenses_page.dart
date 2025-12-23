import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/domain/entities/expense.dart' show Expense;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/expenses_providers.dart';
// اختياري لو عندك ويدجت جاهزة للـPills

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});
  static const route = '/expenses';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(expensesRangeProvider);
    final total = ref.watch(expensesTotalProvider);
    final list = ref.watch(expensesListProvider);

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
                AppStrings.expensesTitle,
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
                  tooltip: AppStrings.actionFilterByDate,
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(DateTime.now().year - 2),
                      lastDate: DateTime(DateTime.now().year + 1),
                      initialDateRange: range,
                      locale: const Locale('ar'),
                      builder: (context, child) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      // نثبت بداية كل يوم 4 ص ونهاية اليوم التالي 4 ص
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
                      ref.read(expensesRangeProvider.notifier).state =
                          DateTimeRange(start: start, end: end);
                    }
                  },
                  icon: const Icon(Icons.filter_alt_rounded),
                  color: Colors.white,
                ),
                if (range != todayOperationalRangeLocal())
                  IconButton(
                    tooltip: AppStrings.actionOperationalDay,
                    onPressed: () {
                      ref.read(expensesRangeProvider.notifier).state =
                          todayOperationalRangeLocal();
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
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditSheet(context, ref),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.expenseNew),
          backgroundColor: kDarkBrown,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // شريط علوي صغير: إجمالي + فلتر تاريخ
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  _pill(
                    context,
                    AppStrings.totalLabel,
                    total.toStringAsFixed(2),
                    Icons.account_balance_wallet,
                  ),
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 6),

            Expanded(
              child: list.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(AppStrings.expensesLoadError(e))),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(AppStrings.expensesEmptyRange),
                    );
                  }

                  // تجميع حسب “يوم تشغيلي” بالتحويل -4 ساعات
                  DateTime shiftForOpDay(DateTime utc) =>
                      utc.subtract(const Duration(hours: 4));
                  final Map<String, List<int>> groups = {}; // dayKey -> indices
                  for (int i = 0; i < items.length; i++) {
                    final s = shiftForOpDay(items[i].createdAtUtc);
                    final key =
                        '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
                    groups.putIfAbsent(key, () => []).add(i);
                  }
                  final dayKeys = groups.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  double sumFor(List<int> idxs) {
                    double s = 0;
                    for (final i in idxs) {
                      s += items[i].amount;
                    }
                    return s;
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: dayKeys.length,
                    itemBuilder: (context, i) {
                      final day = dayKeys[i];
                      final idxs = groups[day]!;
                      final dayTotal = sumFor(idxs);

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    day,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  _pill(
                                    context,
                                    AppStrings.dailyTotalLabel,
                                    dayTotal.toStringAsFixed(2),
                                    Icons.summarize,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Divider(height: 14),
                              ...idxs.map((ii) {
                                final e = items[ii];
                                final hh = e.createdAtUtc.hour
                                    .toString()
                                    .padLeft(2, '0');
                                final mm = e.createdAtUtc.minute
                                    .toString()
                                    .padLeft(2, '0');
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.brown.shade100,
                                    child: const Icon(
                                      Icons.payments,
                                      color: Colors.brown,
                                    ),
                                  ),
                                  title: Text(
                                    e.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '$hh:$mm',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        e.amount.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: AppStrings.actionEdit,
                                        onPressed: () =>
                                            _openEditSheet(context, ref, e),
                                        icon: const Icon(Icons.edit),
                                      ),
                                      IconButton(
                                        tooltip: AppStrings.actionDelete,
                                        onPressed: () =>
                                            _deleteExpense(context, ref, e.id),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kDarkBrown),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.confirmDeleteTitle),
        content: const Text(AppStrings.expenseDeleteConfirm),
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
      await ref.read(deleteExpenseProvider)(id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.expenseDeleted)));
      }
    }
  }

  void _openEditSheet(BuildContext context, WidgetRef ref, [Expense? e]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ExpenseEditSheet(expense: e),
    );
  }
}

class _ExpenseEditSheet extends ConsumerStatefulWidget {
  final Expense? expense;
  const _ExpenseEditSheet({this.expense});

  @override
  ConsumerState<_ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends ConsumerState<_ExpenseEditSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _when = DateTime.now();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _notesCtrl.text = e.notes ?? '';
      _when = e.createdAtUtc.toLocal();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 42,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          Text(
            widget.expense == null
                ? AppStrings.expenseNew
                : AppStrings.expenseEditTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _titleCtrl,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: AppStrings.titleLabel,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _amountCtrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.amountLabel,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _notesCtrl,
            textAlign: TextAlign.center,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: AppStrings.notesOptionalLabel,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(DateTime.now().year - 2),
                      lastDate: DateTime(DateTime.now().year + 1),
                      initialDate: _when,
                      locale: const Locale('ar'),
                      builder: (context, child) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _when = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          _when.hour,
                          _when.minute,
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.today),
                  label: Text(
                    '${_when.year}-${_when.month.toString().padLeft(2, '0')}-${_when.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _when.hour,
                        minute: _when.minute,
                      ),
                      builder: (context, child) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: child!,
                      ),
                    );
                    if (t != null) {
                      setState(() {
                        _when = DateTime(
                          _when.year,
                          _when.month,
                          _when.day,
                          t.hour,
                          t.minute,
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    '${_when.hour.toString().padLeft(2, '0')}:${_when.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text(AppStrings.actionCancel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kDarkBrown,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : () => _save(context),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text(AppStrings.actionSave),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.enterTitlePrompt)));
      return;
    }
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text(AppStrings.enterValidAmountPrompt)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final fnAdd = ref.read(addExpenseProvider);
      final fnUpd = ref.read(updateExpenseProvider);

      if (widget.expense == null) {
        await fnAdd(
          _titleCtrl.text.trim(),
          amount,
          whenUtc: _when.toUtc(),
          notes: _notesCtrl.text.trim(),
        );
      } else {
        await fnUpd(
          widget.expense!.copyWith(
            title: _titleCtrl.text.trim(),
            amount: amount,
            createdAtUtc: _when.toUtc(),
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          ),
        );
      }

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.expense == null
                ? AppStrings.expenseAdded
                : AppStrings.expenseUpdated,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
