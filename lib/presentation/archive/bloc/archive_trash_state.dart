import 'package:elfouad_admin/presentation/expenses/utils/expenses_utils.dart';
import 'package:elfouad_admin/presentation/archive/models/archive_entry.dart';
import 'package:flutter/material.dart';

enum ArchiveFilter {
  all,
  sales,
  products,
  expenses,
  inventory,
  recipes,
  extras,
  drinks,
}

class ArchiveTrashState {
  static const Object _sentinel = Object();

  final bool loading;
  final Object? error;
  final List<ArchiveEntry> entries;
  final ArchiveFilter filter;
  final Set<String> restoringIds;
  final DateTimeRange range;

  const ArchiveTrashState({
    required this.loading,
    required this.error,
    required this.entries,
    required this.filter,
    required this.restoringIds,
    required this.range,
  });

  factory ArchiveTrashState.initial() => ArchiveTrashState(
    loading: true,
    error: null,
    entries: [],
    filter: ArchiveFilter.all,
    restoringIds: <String>{},
    range: todayOperationalRangeLocal(),
  );

  ArchiveTrashState copyWith({
    bool? loading,
    Object? error = _sentinel,
    List<ArchiveEntry>? entries,
    ArchiveFilter? filter,
    Set<String>? restoringIds,
    DateTimeRange? range,
  }) {
    return ArchiveTrashState(
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error,
      entries: entries ?? this.entries,
      filter: filter ?? this.filter,
      restoringIds: restoringIds ?? this.restoringIds,
      range: range ?? this.range,
    );
  }

  bool isRestoring(String id) => restoringIds.contains(id);
}
