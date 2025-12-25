import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ????? ???????
enum InventoryTab { all, singles, blends, extras, drinks }

// ????? ??? ??????
double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

// ?? ????? ??????? ???????? ??????????
class InventoryRow {
  final String id;
  final String name;
  final String variant; // ???? ???????
  final double stockG; // ??????
  final double minLevelG; // ?? ???? ??????
  final double sellPerKg; // ???/???
  final double costPerKg; // ?????/???
  final String coll; // 'singles' | 'blends'
  final DocumentReference<Map<String, dynamic>> ref;

  const InventoryRow({
    required this.id,
    required this.name,
    required this.variant,
    required this.stockG,
    required this.minLevelG,
    required this.sellPerKg,
    required this.costPerKg,
    required this.coll,
    required this.ref,
  });

  bool get isSingle => coll == 'singles';
  bool get isBlend => coll == 'blends';
  bool get isExtra => false;
}

class ExtraInventoryRow {
  final String id;
  final String name;
  final String category;
  final bool active;
  final double priceSell;
  final double costUnit;
  final double stockUnits;
  final String unit;
  final DocumentReference<Map<String, dynamic>> ref;

  const ExtraInventoryRow({
    required this.id,
    required this.name,
    required this.category,
    required this.active,
    required this.priceSell,
    required this.costUnit,
    required this.stockUnits,
    required this.unit,
    required this.ref,
  });
}

double _stockGFrom(Map<String, dynamic> m) {
  // ????? ???????: stock ?? ???? ??????? ???????
  final keys = [
    'stock',
    'stock_grams',
    'available_grams',
    'in_stock_grams',
    'grams_in_stock',
  ];
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v.replaceAll(',', '.'));
      if (p != null) return p;
    }
  }
  return 0.0;
}

InventoryRow _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? <String, dynamic>{};
  final sell = _d(
    m['sellPricePerKg'] ?? m['sellPerKg'] ?? m['sell_price_per_kg'],
  );
  final cost = _d(
    m['costPricePerKg'] ?? m['costPerKg'] ?? m['cost_price_per_kg'],
  );
  return InventoryRow(
    id: d.id,
    name: '${m['name'] ?? ''}',
    variant: '${m['variant'] ?? ''}',
    stockG: _stockGFrom(m), // ??? ???????
    minLevelG: _d(m['minLevel']),
    sellPerKg: sell,
    costPerKg: cost,
    coll: d.reference.parent.id,
    ref: d.reference,
  );
}

double _extraNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9.,-]'), '');
      final parsed = double.tryParse(sanitized.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

String _extraString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

bool _extraBool(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
  }
  return true;
}

ExtraInventoryRow _extraFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data();
  return ExtraInventoryRow(
    id: d.id,
    name: _extraString(data, ['name', 'title', 'label']),
    category: _extraString(data, ['category', 'type', 'group']),
    active: _extraBool(data, ['active', 'isActive', 'enabled']),
    priceSell: _extraNumber(data, [
      'price_sell',
      'priceSell',
      'sellPrice',
      'sell_price',
      'price',
    ]),
    costUnit: _extraNumber(data, [
      'cost_unit',
      'costUnit',
      'costPrice',
      'cost',
      'purchase_price',
    ]),
    stockUnits: _extraNumber(data, [
      'stock_units',
      'stock',
      'quantity',
      'available',
      'inventory',
    ]),
    unit: _extraString(data, ['unit', 'unitName', 'unit_name']),
    ref: d.reference,
  );
}

// helper: sort ?????? (????? ?? ???????)
List<InventoryRow> _sortByNameVariant(Iterable<InventoryRow> it) {
  final list = it.toList();
  list.sort((a, b) {
    final n = a.name.compareTo(b.name);
    if (n != 0) return n;
    return a.variant.compareTo(b.variant);
  });
  return list;
}

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
        return const <InventoryRow>[]; // ????????? ???? ????? ????????
      case InventoryTab.all:
        return [...blends, ...singles];
    }
  }

  double get maxStock {
    double max = 0;
    for (final r in [...singles, ...blends]) {
      if (r.stockG > max) max = r.stockG;
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

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(
          const InventoryState(
            tab: InventoryTab.all,
            singles: [],
            blends: [],
            extras: [],
            loadingSingles: true,
            loadingBlends: true,
            loadingExtras: true,
            error: null,
          ),
        ) {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<List<InventoryRow>>? _singlesSub;
  StreamSubscription<List<InventoryRow>>? _blendsSub;
  StreamSubscription<List<ExtraInventoryRow>>? _extrasSub;

  void setTab(InventoryTab tab) => emit(state.copyWith(tab: tab));

  void _subscribe() {
    _singlesSub = _firestore
        .collection('singles')
        .orderBy('name')
        .snapshots()
        .map((s) => _sortByNameVariant(s.docs.map(_fromDoc)))
        .listen(
          (rows) => emit(
            state.copyWith(
              singles: rows,
              loadingSingles: false,
              error: null,
            ),
          ),
          onError: (e, _) => emit(
            state.copyWith(loadingSingles: false, error: e),
          ),
        );

    _blendsSub = _firestore
        .collection('blends')
        .orderBy('name')
        .snapshots()
        .map((s) => _sortByNameVariant(s.docs.map(_fromDoc)))
        .listen(
          (rows) => emit(
            state.copyWith(
              blends: rows,
              loadingBlends: false,
              error: null,
            ),
          ),
          onError: (e, _) => emit(
            state.copyWith(loadingBlends: false, error: e),
          ),
        );

    _extrasSub = _firestore
        .collection('extras')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(_extraFromDoc).toList())
        .listen(
          (rows) => emit(
            state.copyWith(
              extras: rows,
              loadingExtras: false,
              error: null,
            ),
          ),
          onError: (e, _) => emit(
            state.copyWith(loadingExtras: false, error: e),
          ),
        );
  }

  @override
  Future<void> close() async {
    await _singlesSub?.cancel();
    await _blendsSub?.cancel();
    await _extrasSub?.cancel();
    return super.close();
  }
}

// CRUD (????? ???? ??? singles/blends - ??????? ???? ?? ???????? ?? ???)
Future<void> updateInventoryRow(
  InventoryRow r, {
  String? name,
  String? variant,
  double? stockG,
  double? sellPerKg,
  double? costPerKg,
  double? minLevelG,
}) async {
  final data = <String, dynamic>{};
  if (name != null) data['name'] = name;
  if (variant != null) data['variant'] = variant;

  if (stockG != null) {
    if (r.isExtra) {
      data['stock_units'] = stockG; // ?? Extra ???? ?? stock_units
    } else {
      data['stock'] = stockG; // ???? ???? ?? stock (??????)
    }
  }

  if (!r.isExtra) {
    if (sellPerKg != null) data['sellPricePerKg'] = sellPerKg;
    if (costPerKg != null) data['costPricePerKg'] = costPerKg;
    if (minLevelG != null) data['minLevel'] = minLevelG;
  } else {
    if (minLevelG != null) data['min_units'] = minLevelG; // ?? ???? ?????
  }

  await r.ref.update(data);
}

Future<void> deleteInventoryRow(InventoryRow r) => r.ref.delete();

Future<void> createInventoryRow({
  required bool isBlend,
  required String name,
  String variant = '',
  required double stockG,
  required double sellPerKg,
  required double costPerKg,
  double minLevelG = 0,
}) async {
  final col = FirebaseFirestore.instance.collection(
    isBlend ? 'blends' : 'singles',
  );
  await col.add({
    'name': name,
    'variant': variant,
    'stock': stockG,
    'sellPricePerKg': sellPerKg,
    'costPricePerKg': costPerKg,
    'minLevel': minLevelG,
    'unit': 'g',
    'createdAt': DateTime.now().toUtc(),
  });
}
