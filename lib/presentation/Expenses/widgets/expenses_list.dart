import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/domain/entities/expense.dart';
import 'package:flutter/material.dart';

import 'expense_summary_pill.dart';

class ExpensesList extends StatelessWidget {
  const ExpensesList({
    super.key,
    required this.items,
    required this.horizontalPadding,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Expense> items;
  final double horizontalPadding;
  final void Function(Expense e) onEdit;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    // Align with the 4 AM operational day cutoff.
    DateTime shiftForOpDay(DateTime utc) =>
        utc.subtract(const Duration(hours: 4));
    final Map<String, List<int>> groups = {}; // dayKey -> indices
    for (int i = 0; i < items.length; i++) {
      final s = shiftForOpDay(items[i].createdAtUtc);
      final key =
          '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(i);
    }
    final dayKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    double sumFor(List<int> idxs) {
      double s = 0;
      for (final i in idxs) {
        s += items[i].amount;
      }
      return s;
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 100),
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
                    ExpenseSummaryPill(
                      label: AppStrings.dailyTotalLabel,
                      value: dayTotal.toStringAsFixed(2),
                      icon: Icons.summarize,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 14),
                ...idxs.map((ii) {
                  final e = items[ii];
                  final hh = e.createdAtUtc.hour.toString().padLeft(2, '0');
                  final mm = e.createdAtUtc.minute.toString().padLeft(2, '0');
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
                          onPressed: () => onEdit(e),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: AppStrings.actionDelete,
                          onPressed: () => onDelete(e.id),
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
  }
}
