import 'package:elfouad_admin/presentation/archive/models/archive_entry.dart';

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
  final bool loading;
  final Object? error;
  final List<ArchiveEntry> entries;
  final ArchiveFilter filter;
  final Set<String> restoringIds;

  const ArchiveTrashState({
    required this.loading,
    required this.error,
    required this.entries,
    required this.filter,
    required this.restoringIds,
  });

  factory ArchiveTrashState.initial() => const ArchiveTrashState(
        loading: true,
        error: null,
        entries: [],
        filter: ArchiveFilter.all,
        restoringIds: <String>{},
      );

  ArchiveTrashState copyWith({
    bool? loading,
    Object? error,
    List<ArchiveEntry>? entries,
    ArchiveFilter? filter,
    Set<String>? restoringIds,
  }) {
    return ArchiveTrashState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
      entries: entries ?? this.entries,
      filter: filter ?? this.filter,
      restoringIds: restoringIds ?? this.restoringIds,
    );
  }

  bool isRestoring(String id) => restoringIds.contains(id);
}
