import 'dart:async';

import 'package:elfouad_admin/data/data_source/firestore_expenses_ds.dart';
import 'package:elfouad_admin/domain/entities/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// ????? ????? (?? ??????? ?? ??????)
const kDarkBrown = Color(0xFF543824);
const kBeige = Color(0xFFC49A6C);

/// ????? ???????? ??????? ???? 4 ?
DateTimeRange todayOperationalRangeLocal() {
  final now = DateTime.now();
  final today4 = DateTime(now.year, now.month, now.day, 4);
  final start = now.isBefore(today4)
      ? today4.subtract(const Duration(days: 1))
      : today4;
  final end = start.add(const Duration(days: 1));
  return DateTimeRange(start: start, end: end);
}

class ExpensesState {
  final DateTimeRange range;
  final List<Expense> items;
  final bool loading;
  final Object? error;

  const ExpensesState({
    required this.range,
    required this.items,
    required this.loading,
    required this.error,
  });

  double get total =>
      items.fold<double>(0.0, (s, e) => s + e.amount);

  ExpensesState copyWith({
    DateTimeRange? range,
    List<Expense>? items,
    bool? loading,
    Object? error,
  }) {
    return ExpensesState(
      range: range ?? this.range,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class ExpensesCubit extends Cubit<ExpensesState> {
  ExpensesCubit({FirestoreExpensesDs? ds})
      : _ds = ds ?? FirestoreExpensesDs(),
        super(
          ExpensesState(
            range: todayOperationalRangeLocal(),
            items: const [],
            loading: true,
            error: null,
          ),
        ) {
    _subscribe(state.range);
  }

  final FirestoreExpensesDs _ds;
  StreamSubscription<List<Expense>>? _sub;

  void setRange(DateTimeRange range) {
    emit(state.copyWith(range: range, loading: true, error: null));
    _subscribe(range);
  }

  Future<void> addExpense(
    String title,
    double amount, {
    DateTime? whenUtc,
    String? notes,
    String? category,
  }) {
    return _ds.add(
      title,
      amount,
      whenUtc: whenUtc,
      notes: notes,
      category: category,
    );
  }

  Future<void> updateExpense(Expense e) => _ds.update(e);

  Future<void> deleteExpense(String id) => _ds.delete(id);

  void _subscribe(DateTimeRange range) {
    _sub?.cancel();
    _sub = _ds.watchInRange(range.start.toUtc(), range.end.toUtc()).listen(
      (items) => emit(
        state.copyWith(items: items, loading: false, error: null),
      ),
      onError: (e, _) => emit(
        state.copyWith(loading: false, error: e),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
