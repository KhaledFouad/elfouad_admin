import 'package:elfouad_admin/domain/entities/expense.dart';
import 'package:flutter/material.dart';

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

  double get total => items.fold<double>(0.0, (s, e) => s + e.amount);

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
