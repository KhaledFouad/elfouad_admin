import 'dart:async';

import 'package:elfouad_admin/data/data_source/firestore_expenses_ds.dart';
import 'package:elfouad_admin/domain/entities/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../utils/expenses_utils.dart';
import 'expenses_state.dart';

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
    _sub = _ds
        .watchInRange(range.start.toUtc(), range.end.toUtc())
        .listen(
          (items) =>
              emit(state.copyWith(items: items, loading: false, error: null)),
          onError: (e, _) => emit(state.copyWith(loading: false, error: e)),
        );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
