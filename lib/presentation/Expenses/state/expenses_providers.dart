import 'package:elfouad_admin/data/data_source/firestore_expenses_ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../domain/entities/expense.dart';

/// ألوان ثابتة (لو محتاجها في ويدجتس)
const kDarkBrown = Color(0xFF543824);
const kBeige = Color(0xFFC49A6C);

/// اليوم التشغيلي محلياً، يبدأ 4 ص
DateTimeRange todayOperationalRangeLocal() {
  final now = DateTime.now();
  final today4 = DateTime(now.year, now.month, now.day, 4);
  final start = now.isBefore(today4)
      ? today4.subtract(const Duration(days: 1))
      : today4;
  final end = start.add(const Duration(days: 1));
  return DateTimeRange(start: start, end: end);
}

/// نحتفظ بالمدى المحدد
final expensesRangeProvider = StateProvider<DateTimeRange>((ref) {
  return todayOperationalRangeLocal();
});

final _dsProvider = Provider<FirestoreExpensesDs>(
  (ref) => FirestoreExpensesDs(),
);

/// Stream بالمصروفات داخل المدى (محولة إلى UTC في الاستعلام)
final expensesListProvider = StreamProvider<List<Expense>>((ref) {
  final r = ref.watch(expensesRangeProvider);
  return ref.watch(_dsProvider).watchInRange(r.start.toUtc(), r.end.toUtc());
});

/// إجمالي المبلغ في المدى
final expensesTotalProvider = Provider<double>((ref) {
  final list = ref.watch(expensesListProvider).value ?? const <Expense>[];
  double s = 0;
  for (final e in list) {
    s += e.amount;
  }
  return s;
});

/// عمليات CRUD مختصرة
final addExpenseProvider =
    Provider<
      Future<void> Function(
        String title,
        double amount, {
        DateTime? whenUtc,
        String? notes,
        String? category,
      })
    >((ref) {
      final ds = ref.watch(_dsProvider);
      return (
        String title,
        double amount, {
        DateTime? whenUtc,
        String? notes,
        String? category,
      }) => ds.add(
        title,
        amount,
        whenUtc: whenUtc,
        notes: notes,
        category: category,
      );
    });

final updateExpenseProvider = Provider<Future<void> Function(Expense e)>((ref) {
  final ds = ref.watch(_dsProvider);
  return (Expense e) => ds.update(e);
});

final deleteExpenseProvider = Provider<Future<void> Function(String id)>((ref) {
  final ds = ref.watch(_dsProvider);
  return (String id) => ds.delete(id);
});
