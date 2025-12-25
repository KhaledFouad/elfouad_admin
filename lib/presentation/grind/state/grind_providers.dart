import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0.0;
}

class InventoryRow {
  final String id;
  final String name;
  final String variant;
  final double stockG;
  final String coll; // 'singles' or 'blends'
  final DocumentReference<Map<String, dynamic>> ref;
  const InventoryRow({
    required this.id,
    required this.name,
    required this.variant,
    required this.stockG,
    required this.coll,
    required this.ref,
  });
}

InventoryRow _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? {};
  return InventoryRow(
    id: d.id,
    name: '${m['name'] ?? ''}',
    variant: '${m['variant'] ?? ''}',
    stockG: _d(m['stock']),
    coll: d.reference.parent.id,
    ref: d.reference,
  );
}

int _blendRank(String name) {
  final n = name.trim();
  if (n.contains('????????')) return 0;
  if (n.contains('?????')) return 1;
  if (n.contains('??????')) return 2;
  if (n.contains('???????') || n.contains('??????')) return 3;
  return 4;
}

class GrindState {
  final List<InventoryRow> items;
  final String query;
  final bool loading;
  final Object? error;

  const GrindState({
    required this.items,
    required this.query,
    required this.loading,
    required this.error,
  });

  List<InventoryRow> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((r) {
      final t = '${r.name} ${r.variant}'.toLowerCase();
      return t.contains(q);
    }).toList();
  }

  GrindState copyWith({
    List<InventoryRow>? items,
    String? query,
    bool? loading,
    Object? error,
  }) {
    return GrindState(
      items: items ?? this.items,
      query: query ?? this.query,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class GrindCubit extends Cubit<GrindState> {
  GrindCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(
          const GrindState(items: [], query: '', loading: true, error: null),
        ) {
    _subscribe();
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<List<InventoryRow>>? _singlesSub;
  StreamSubscription<List<InventoryRow>>? _blendsSub;

  void setQuery(String q) => emit(state.copyWith(query: q));

  void _subscribe() {
    _singlesSub = _firestore
        .collection('singles')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList())
        .listen(
          (rows) => _emitCombined(singles: rows),
          onError: (e, _) => emit(
            state.copyWith(loading: false, error: e),
          ),
        );

    _blendsSub = _firestore
        .collection('blends')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList())
        .listen(
          (rows) => _emitCombined(blends: rows),
          onError: (e, _) => emit(
            state.copyWith(loading: false, error: e),
          ),
        );
  }

  void _emitCombined({List<InventoryRow>? singles, List<InventoryRow>? blends}) {
    final nextSingles = singles ?? state.items.where((i) => i.coll == 'singles').toList();
    final nextBlends = blends ?? state.items.where((i) => i.coll == 'blends').toList();

    nextBlends.sort((a, b) {
      final r = _blendRank(a.name).compareTo(_blendRank(b.name));
      if (r != 0) return r;
      final c = a.name.compareTo(b.name);
      if (c != 0) return c;
      return a.variant.compareTo(b.variant);
    });

    nextSingles.sort((a, b) {
      final c = a.name.compareTo(b.name);
      if (c != 0) return c;
      return a.variant.compareTo(b.variant);
    });

    emit(
      state.copyWith(
        items: [...nextBlends, ...nextSingles],
        loading: false,
        error: null,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _singlesSub?.cancel();
    await _blendsSub?.cancel();
    return super.close();
  }
}

/// ??? ??? ???? ????????? (???? ????? ?? ??????? ??? ?? ??? ?? ???????)
Future<void> grindAndDeduct({
  required InventoryRow item,
  required double grams,
  required bool isSpiced, // ??????? ?? ???????
}) async {
  if (grams <= 0) return;

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(item.ref);
    final m = snap.data() ?? {};
    final cur = _d(m['stock']);

    if (cur <= 0) {
      throw StateError('empty_stock');
    }
    if (grams > cur) {
      throw StateError('insufficient_stock');
    }

    final newStock = (cur - grams).clamp(0.0, double.infinity);
    tx.update(item.ref, {'stock': newStock});
  });
}
