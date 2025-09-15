import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../domain/use_cases/get_sales_in_range.dart';
import '../../../../domain/use_cases/build_breakdowns.dart';
import '../../../../data/repo/sales_repo_impl.dart';
import '../../../../data/data_source/firestore_sales_ds.dart';

class SalesState {
  final bool loading;
  final dynamic data;
  final String? error;
  SalesState({this.loading = false, this.data, this.error});

  SalesState copyWith({bool? loading, dynamic data, String? error}) =>
      SalesState(
        loading: loading ?? this.loading,
        data: data ?? this.data,
        error: error,
      );
}

final salesControllerProvider =
    StateNotifierProvider<SalesController, SalesState>((ref) {
      final ds = FirestoreSalesDs(FirebaseFirestore.instance);
      final repo = SalesRepoImpl(ds);
      final getSales = GetSalesInRange(repo);
      final build = BuildBreakdowns();
      return SalesController(getSales, build);
    });

class SalesController extends StateNotifier<SalesState> {
  final GetSalesInRange _getSales;
  final BuildBreakdowns _build;
  SalesController(this._getSales, this._build) : super(SalesState());

  Future<void> fetch(DateTime startUtc, DateTime endUtc) async {
    if (!mounted) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _getSales(startUtc, endUtc);
      if (!mounted) return;
      final b = _build(list);
      state = SalesState(loading: false, data: b);
    } catch (e) {
      if (!mounted) return;
      state = SalesState(loading: false, error: e.toString());
    }
  }
}
