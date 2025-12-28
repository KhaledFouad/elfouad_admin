import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/data/repo/sales_history_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/sale_record.dart';
import '../models/sales_day_group.dart';
import '../models/credit_account.dart';
import '../utils/sale_utils.dart';
import 'sales_history_state.dart';

class SalesHistoryCubit extends Cubit<SalesHistoryState> {
  SalesHistoryCubit({required SalesHistoryRepository repository})
    : _repository = repository,
      super(SalesHistoryState.initial());

  final SalesHistoryRepository _repository;

  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  Future<void> initialize() async {
    unawaited(_loadCreditUnpaidCount());
    await _loadFirstPage();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));

    final range = state.range;
    final page = await _repository.fetchPage(
      range: range,
      startAfter: _lastDoc,
    );

    _lastDoc = page.lastDoc;

    final moreRecords = page.docs.map(SaleRecord.new).toList();
    final existing = List<SaleRecord>.from(state.allRecords);
    final existingIds = existing.map((e) => e.id).toSet();
    for (final r in moreRecords) {
      if (!existingIds.contains(r.id)) {
        existing.add(r);
      }
    }

    emit(
      state.copyWith(
        allRecords: existing,
        groups: _buildGroups(existing, range),
        hasMore: page.hasMore,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> setRange(DateTimeRange? range) async {
    final resolved = range ?? defaultSalesRange();
    emit(state.copyWith(customRange: range, range: resolved));
    await _loadFirstPage();
  }

  DateTimeRange normalizePickerRange(DateTimeRange picked) {
    final start = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
      4,
    );
    final endBase = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      4,
    );
    return DateTimeRange(
      start: start,
      end: endBase.add(const Duration(days: 1)),
    );
  }

  Future<void> settleDeferredSale(String saleId) async {
    await _repository.settleDeferredSale(saleId);
    await _loadFirstPage();
    unawaited(_loadCreditUnpaidCount());
    unawaited(_loadCreditAccounts());
  }

  Future<void> applyCreditPayment({
    required String customerName,
    required double amount,
  }) async {
    await _repository.applyCreditPayment(
      customerName: customerName,
      amount: amount,
    );
    await _loadFirstPage();
    unawaited(_loadCreditUnpaidCount());
    unawaited(_loadCreditAccounts());
  }

  Future<void> deleteCreditCustomer(String customerName) async {
    await _repository.deleteCreditCustomer(customerName);
    await _loadFirstPage();
    unawaited(_loadCreditUnpaidCount());
    unawaited(_loadCreditAccounts());
  }

  Future<void> deleteSale(String saleId) async {
    await _repository.deleteSaleWithRollback(saleId);
    await refreshCurrent();
  }

  Future<void> refreshCurrent() async {
    await _loadFirstPage();
    unawaited(_loadCreditUnpaidCount());
    unawaited(_loadCreditAccounts());
  }

  Future<void> loadCreditAccounts({bool force = false}) async {
    if (state.isCreditLoading) return;
    if (!force && state.creditAccounts.isNotEmpty) return;
    await _loadCreditAccounts();
  }

  Future<void> _loadFirstPage() async {
    emit(
      state.copyWith(
        isLoadingFirst: true,
        isLoadingMore: false,
        hasMore: true,
        isRangeTotalLoading: true,
        fullTotalsByDay: const {},
      ),
    );

    final range = state.range;
    _lastDoc = null;

    final page = await _repository.fetchPage(range: range, startAfter: null);

    _lastDoc = page.lastDoc;

    final records = page.docs.map(SaleRecord.new).toList();

    emit(
      state.copyWith(
        groups: _buildGroups(records, range),
        allRecords: records,
        hasMore: page.hasMore,
        isLoadingFirst: false,
      ),
    );

    unawaited(_loadFullTotalsPerDay(range));
  }

  Future<void> _loadCreditAccounts() async {
    emit(state.copyWith(isCreditLoading: true));
    try {
      final docs = await _repository.fetchCreditSales();
      final records = docs.map(SaleRecord.new).toList();
      final accounts = _buildCreditAccounts(records);
      final unpaidCount = accounts.fold<int>(
        0,
        (sum, account) => sum + account.unpaidCount,
      );
      emit(
        state.copyWith(
          creditAccounts: accounts,
          isCreditLoading: false,
          creditUnpaidCount: unpaidCount,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isCreditLoading: false));
    }
  }

  Future<void> _loadCreditUnpaidCount() async {
    if (state.isCreditCountLoading) return;
    emit(state.copyWith(isCreditCountLoading: true));
    try {
      final count = await _repository.fetchUnpaidCreditCount();
      emit(state.copyWith(creditUnpaidCount: count));
    } finally {
      emit(state.copyWith(isCreditCountLoading: false));
    }
  }

  Future<void> _loadFullTotalsPerDay(DateTimeRange range) async {
    try {
      emit(state.copyWith(isRangeTotalLoading: true));

      final baseDocs = await _repository.fetchAllForRange(range: range);
      final paymentDocs = await _repository.fetchPaymentEventsForRange(
        range: range,
      );

      final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in baseDocs) {
        combined[doc.id] = doc;
      }
      for (final doc in paymentDocs) {
        combined[doc.id] = doc;
      }

      final records = combined.values.map(SaleRecord.new).toList();

      bool inRange(DateTime value) {
        return !value.isBefore(range.start) && value.isBefore(range.end);
      }

      final Map<String, double> totals = {};
      for (final record in records) {
        if (record.isComplimentary) continue;
        if (record.isDeferred) {
          final events = record.paymentEvents;
          if (events.isNotEmpty) {
            for (final event in events) {
              if (event.amount <= 0) continue;
              if (!inRange(event.at)) continue;
              final key = _dayKey(event.at);
              totals[key] = (totals[key] ?? 0) + event.amount;
            }
          } else if (record.isPaid && record.settledAt != null) {
            final settledAt = record.settledAt!;
            if (inRange(settledAt)) {
              final key = _dayKey(settledAt);
              totals[key] = (totals[key] ?? 0) + record.totalPrice;
            }
          }
          continue;
        }

        if (record.isPaid) {
          final key = _dayKey(record.effectiveTime);
          totals[key] = (totals[key] ?? 0) + record.totalPrice;
        }
      }

      emit(state.copyWith(fullTotalsByDay: totals));
    } finally {
      emit(state.copyWith(isRangeTotalLoading: false));
    }
  }

  List<SalesDayGroup> _buildGroups(
    List<SaleRecord> records,
    DateTimeRange range,
  ) {
    final start = range.start;
    final end = range.end;

    bool inRange(DateTime value) {
      return !value.isBefore(start) && value.isBefore(end);
    }

    final filtered = <SaleRecord>[];
    for (final record in records) {
      final effective = record.effectiveTime;
      final include =
          (!record.isDeferred && inRange(effective)) ||
          (record.isDeferred && record.isPaid && inRange(effective));
      if (include) {
        filtered.add(record);
      }
    }

    final Map<String, List<SaleRecord>> grouped = {};
    for (final record in filtered) {
      final effective = record.effectiveTime;
      final key = _dayKey(effective);
      grouped.putIfAbsent(key, () => <SaleRecord>[]).add(record);
    }

    final dayKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return dayKeys.map((key) {
      final entries = grouped[key]!;
      final totalPaid = _sumPaidOnly(entries);
      return SalesDayGroup(label: key, entries: entries, totalPaid: totalPaid);
    }).toList();
  }

  List<CreditCustomerAccount> _buildCreditAccounts(List<SaleRecord> records) {
    final Map<String, List<SaleRecord>> grouped = {};

    for (final record in records) {
      final name = record.note.trim();
      if (name.isEmpty) continue;
      grouped.putIfAbsent(name, () => <SaleRecord>[]).add(record);
    }

    final accounts = grouped.entries.map((entry) {
      final sales = List<SaleRecord>.from(entry.value)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return CreditCustomerAccount(name: entry.key, sales: sales);
    }).toList();

    accounts.sort((a, b) {
      final owedCompare = b.totalOwed.compareTo(a.totalOwed);
      if (owedCompare != 0) return owedCompare;
      return a.name.compareTo(b.name);
    });

    return accounts;
  }

  double _sumPaidOnly(List<SaleRecord> entries) {
    double sum = 0;
    for (final entry in entries) {
      if (!entry.isComplimentary && entry.isPaid) {
        sum += entry.totalPrice;
      }
    }
    return sum;
  }

  String _dayKey(DateTime value) {
    final shifted = shiftDayByFourHours(value);
    return '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
  }
}
