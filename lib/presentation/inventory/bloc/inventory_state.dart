import '../models/extra_inventory_row.dart';
import '../models/inventory_row.dart';
import '../models/inventory_tab.dart';

class InventoryState {
  final InventoryTab tab;
  final List<InventoryRow> singles;
  final List<InventoryRow> blends;
  final List<ExtraInventoryRow> extras;
  final bool loadingSingles;
  final bool loadingBlends;
  final bool loadingExtras;
  final Object? error;

  const InventoryState({
    required this.tab,
    required this.singles,
    required this.blends,
    required this.extras,
    required this.loadingSingles,
    required this.loadingBlends,
    required this.loadingExtras,
    required this.error,
  });

  List<InventoryRow> get listForTab {
    switch (tab) {
      case InventoryTab.singles:
        return singles;
      case InventoryTab.blends:
        return blends;
      case InventoryTab.extras:
        return const <InventoryRow>[];
      case InventoryTab.drinks:
        return const <InventoryRow>[];
      case InventoryTab.all:
        return [...blends, ...singles];
    }
  }

  double get maxStock {
    double max = 0;
    for (final row in [...singles, ...blends]) {
      if (row.stockG > max) max = row.stockG;
    }
    return max <= 0 ? 1 : max;
  }

  bool get loading => loadingSingles || loadingBlends || loadingExtras;

  InventoryState copyWith({
    InventoryTab? tab,
    List<InventoryRow>? singles,
    List<InventoryRow>? blends,
    List<ExtraInventoryRow>? extras,
    bool? loadingSingles,
    bool? loadingBlends,
    bool? loadingExtras,
    Object? error,
  }) {
    return InventoryState(
      tab: tab ?? this.tab,
      singles: singles ?? this.singles,
      blends: blends ?? this.blends,
      extras: extras ?? this.extras,
      loadingSingles: loadingSingles ?? this.loadingSingles,
      loadingBlends: loadingBlends ?? this.loadingBlends,
      loadingExtras: loadingExtras ?? this.loadingExtras,
      error: error,
    );
  }
}
