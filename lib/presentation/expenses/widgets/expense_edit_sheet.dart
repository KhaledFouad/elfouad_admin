import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/domain/entities/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/expenses_cubit.dart';
import '../utils/expenses_utils.dart';

class ExpenseEditSheet extends StatefulWidget {
  final Expense? expense;
  const ExpenseEditSheet({super.key, this.expense});

  @override
  State<ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends State<ExpenseEditSheet> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.enterTitlePrompt)),
      );
      return;
    }
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.enterValidAmountPrompt)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final cubit = context.read<ExpensesCubit>();

      if (widget.expense == null) {
        await cubit.addExpense(
          _titleCtrl.text.trim(),
          amount,
          whenUtc: _when.toUtc(),
          notes: _notesCtrl.text.trim(),
        );
      } else {
        await cubit.updateExpense(
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
