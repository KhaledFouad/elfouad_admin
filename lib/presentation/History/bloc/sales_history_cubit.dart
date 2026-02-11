import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/data/repo/sales_history_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sale_record.dart';
import '../models/sales_day_group.dart';
import '../models/credit_account.dart';
import '../models/history_summary.dart';
import '../models/history_partial_payment.dart';
import '../utils/sale_utils.dart';
import 'sales_history_state.dart';

class SalesHistoryCubit extends Cubit<SalesHistoryState> {
  SalesHistoryCubit({required SalesHistoryRepository repository})
    : _repository = repository,
      super(SalesHistoryState.initial());

  final SalesHistoryRepository _repository;

  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _createdSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _settledSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _createdDeferredSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _settledDeferredSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paymentSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deferredPaymentSub;
  StreamSubscription<int>? _creditCountSub;
  Timer? _realtimeDebounce;
  Timer? _summaryDebounce;
  int _summaryRequestId = 0;
  QuerySnapshot<Map<String, dynamic>>? _lastCreatedSnap;
  QuerySnapshot<Map<String, dynamic>>? _lastSettledSnap;
  QuerySnapshot<Map<String, dynamic>>? _lastCreatedDeferredSnap;
  QuerySnapshot<Map<String, dynamic>>? _lastSettledDeferredSnap;
  QuerySnapshot<Map<String, dynamic>>? _lastPaymentSnap;
  QuerySnapshot<Map<String, dynamic>>? _lastDeferredPaymentSnap;

  Future<void> initialize() async {
    _startCreditCountRealtime();
    unawaited(_loadCreditUnpaidCount());
    _startRealtime(state.range);
    unawaited(_loadSummary(state.range));
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
    emit(
      state.copyWith(
        customRange: range,
        range: resolved,
        summary: null,
        summaryByDay: const {},
      ),
    );
    _startRealtime(resolved);
    unawaited(_loadSummary(resolved));
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

  Future<void> updatePartialPayment({
    required HistoryPartialPayment payment,
    required double newAmount,
  }) async {
    await _repository.updateCreditPaymentEvent(
      saleId: payment.saleId,
      eventId: payment.eventId,
      eventIndex: payment.eventIndex,
      eventAt: payment.at,
      oldAmount: payment.amount,
      newAmount: newAmount,
    );
    await refreshCurrent();
  }

  Future<void> deletePartialPayment({
    required HistoryPartialPayment payment,
  }) async {
    await _repository.deleteCreditPaymentEvent(
      saleId: payment.saleId,
      eventId: payment.eventId,
      eventIndex: payment.eventIndex,
      eventAt: payment.at,
      amount: payment.amount,
    );
    await refreshCurrent();
  }

  Future<void> deleteCreditCustomer(String customerName) async {
    await _repository.deleteCreditCustomer(customerName);
    unawaited(_loadCreditUnpaidCount());
    unawaited(_loadCreditAccounts());
  }

  Future<void> renameCreditCustomer({
    required String oldName,
    required String newName,
  }) async {
    await _repository.renameCreditCustomer(oldName: oldName, newName: newName);
    await _loadCreditAccounts();
  }

  Future<void> deleteSale(String saleId) async {
    await _repository.deleteSaleWithRollback(saleId);
    await refreshCurrent();
  }

  Future<void> refreshCurrent() async {
    await _loadFirstPage();
    unawaited(_loadCreditUnpaidCount());
    unawaited(_loadCreditAccounts());
    unawaited(_loadSummary(state.range));
  }

  Future<String?> exportRangeCsv({DateTimeRange? range}) async {
    final targetRange = range ?? state.range;
    final docs = await _repository.fetchAllForRange(range: targetRange);
    final records = docs.map(SaleRecord.new).toList();
    final filtered = _filterRecordsForRange(records, targetRange);
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.effectiveTime.compareTo(a.effectiveTime));
    final csv = _buildCsv(filtered);
    final file = await _writeCsvFile(csv, targetRange);
    return file.path;
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
    final paymentDocs = await _repository.fetchPaymentEventsForRange(
      range: range,
    );

    _lastDoc = page.lastDoc;

    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in page.docs) {
      combined[doc.id] = doc;
    }
    for (final doc in paymentDocs) {
      combined[doc.id] = doc;
    }
    final records = combined.values.map(SaleRecord.new).toList();

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

  void _startRealtime(DateTimeRange range) {
    _createdSub?.cancel();
    _settledSub?.cancel();
    _createdDeferredSub?.cancel();
    _settledDeferredSub?.cancel();
    _paymentSub?.cancel();
    _deferredPaymentSub?.cancel();
    _summaryDebounce?.cancel();
    _lastCreatedSnap = null;
    _lastSettledSnap = null;
    _lastCreatedDeferredSnap = null;
    _lastSettledDeferredSnap = null;
    _lastPaymentSnap = null;
    _lastDeferredPaymentSnap = null;

    _createdSub = _repository
        .watchCreatedInRange(range, SalesHistoryRepository.pageSize)
        .skip(1)
        .listen((snap) {
          _lastCreatedSnap = snap;
          _scheduleRealtimeMerge(range);
        }, onError: (_) {});
    _settledSub = _repository
        .watchSettledInRange(range, SalesHistoryRepository.pageSize)
        .skip(1)
        .listen((snap) {
          _lastSettledSnap = snap;
          _scheduleRealtimeMerge(range);
        }, onError: (_) {});

    _createdDeferredSub = _repository
        .watchDeferredCreatedInRange(range)
        .skip(1)
        .listen((snap) {
          _lastCreatedDeferredSnap = snap;
          _scheduleRealtimeMerge(range);
        }, onError: (_) {});
    _settledDeferredSub = _repository
        .watchDeferredSettledInRange(range)
        .skip(1)
        .listen((snap) {
          _lastSettledDeferredSnap = snap;
          _scheduleRealtimeMerge(range);
        }, onError: (_) {});
    _paymentSub = _repository.watchPaymentInRange(range).skip(1).listen((snap) {
      _lastPaymentSnap = snap;
      _scheduleRealtimeMerge(range);
    }, onError: (_) {});
    _deferredPaymentSub = _repository
        .watchDeferredPaymentInRange(range)
        .skip(1)
        .listen((snap) {
          _lastDeferredPaymentSnap = snap;
          _scheduleRealtimeMerge(range);
        }, onError: (_) {});
  }

  void _startCreditCountRealtime() {
    _creditCountSub?.cancel();
    emit(state.copyWith(isCreditCountLoading: true));
    _creditCountSub = _repository.watchUnpaidCreditCount().listen(
      (unpaidCount) {
        emit(
          state.copyWith(
            creditUnpaidCount: unpaidCount,
            isCreditCountLoading: false,
          ),
        );
      },
      onError: (_) {
        emit(state.copyWith(isCreditCountLoading: false));
      },
    );
  }

  void _scheduleRealtimeMerge(DateTimeRange range) {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _applyRealtimeMerge(range),
    );
  }

  void _applyRealtimeMerge(DateTimeRange range) {
    final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    if (_lastCreatedSnap != null) {
      for (final doc in _lastCreatedSnap!.docs) {
        combined[doc.id] = doc;
      }
    }
    if (_lastSettledSnap != null) {
      for (final doc in _lastSettledSnap!.docs) {
        combined[doc.id] = doc;
      }
    }
    if (_lastCreatedDeferredSnap != null) {
      for (final doc in _lastCreatedDeferredSnap!.docs) {
        combined[doc.id] = doc;
      }
    }
    if (_lastSettledDeferredSnap != null) {
      for (final doc in _lastSettledDeferredSnap!.docs) {
        combined[doc.id] = doc;
      }
    }
    if (_lastPaymentSnap != null) {
      for (final doc in _lastPaymentSnap!.docs) {
        combined[doc.id] = doc;
      }
    }
    if (_lastDeferredPaymentSnap != null) {
      for (final doc in _lastDeferredPaymentSnap!.docs) {
        combined[doc.id] = doc;
      }
    }

    if (combined.isEmpty) return;

    final updated = combined.values.map(SaleRecord.new).toList()
      ..sort((a, b) => b.effectiveTime.compareTo(a.effectiveTime));

    final existing = List<SaleRecord>.from(state.allRecords);
    final updatedIds = updated.map((r) => r.id).toSet();
    final merged = <SaleRecord>[...updated];
    for (final record in existing) {
      if (!updatedIds.contains(record.id)) {
        merged.add(record);
      }
    }

    debugPrint(
      '[HISTORY] realtime first page updated via snapshots, no full-range scans',
    );
    emit(
      state.copyWith(allRecords: merged, groups: _buildGroups(merged, range)),
    );

    _scheduleSummaryRefresh(range);
  }

  void _scheduleSummaryRefresh(DateTimeRange range) {
    _summaryDebounce?.cancel();
    _summaryDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_loadSummary(range));
      unawaited(_loadFullTotalsPerDay(range));
    });
  }

  Future<void> _loadSummary(DateTimeRange range) async {
    final requestId = ++_summaryRequestId;
    emit(state.copyWith(isSummaryLoading: true));
    try {
      final docs = await _repository.fetchAllForRange(range: range);
      final records = docs.map(SaleRecord.new).toList();
      final filtered = _filterRecordsForRange(records, range);
      final summary = HistorySummary.fromRecords(filtered);

      final Map<String, List<SaleRecord>> grouped = {};
      for (final record in filtered) {
        final key = _dayKey(record.effectiveTime);
        grouped.putIfAbsent(key, () => <SaleRecord>[]).add(record);
      }
      final summariesByDay = <String, HistorySummary>{};
      grouped.forEach((key, items) {
        summariesByDay[key] = HistorySummary.fromRecords(items);
      });

      if (requestId == _summaryRequestId) {
        emit(
          state.copyWith(
            summary: summary,
            summaryByDay: summariesByDay,
            isSummaryLoading: false,
          ),
        );
      }
    } catch (_) {
      if (requestId == _summaryRequestId) {
        emit(state.copyWith(isSummaryLoading: false));
      }
    }
  }

  Future<void> _loadCreditAccounts() async {
    emit(state.copyWith(isCreditLoading: true));
    try {
      final docs = await _repository.fetchCreditSales();
      final records = docs.map(SaleRecord.new).toList();
      final accounts = _buildCreditAccounts(records);
      final unpaidCount = accounts.fold<int>(
        0,
        (total, account) => total + account.unpaidCount,
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
          } else {
            final fallbackAmount = parseDouble(
              record.data['last_payment_amount'],
            );
            final fallbackAt = parseOptionalDate(
              record.data['last_payment_at'],
            );
            if (fallbackAmount > 0 &&
                fallbackAt != null &&
                inRange(fallbackAt)) {
              final key = _dayKey(fallbackAt);
              totals[key] = (totals[key] ?? 0) + fallbackAmount;
            } else if (record.isPaid && record.settledAt != null) {
              final settledAt = record.settledAt!;
              if (inRange(settledAt)) {
                final key = _dayKey(settledAt);
                totals[key] = (totals[key] ?? 0) + record.totalPrice;
              }
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
    final filtered = _filterRecordsForRange(records, range);
    final partialPayments = _collectPartialPayments(records, range);

    final Map<String, List<SaleRecord>> grouped = {};
    for (final record in filtered) {
      final effective = record.effectiveTime;
      final key = _dayKey(effective);
      grouped.putIfAbsent(key, () => <SaleRecord>[]).add(record);
    }

    final Map<String, List<HistoryPartialPayment>> paymentsByDay = {};
    for (final payment in partialPayments) {
      final key = _dayKey(payment.at);
      paymentsByDay
          .putIfAbsent(key, () => <HistoryPartialPayment>[])
          .add(payment);
    }

    final dayKeys = <String>{...grouped.keys, ...paymentsByDay.keys}.toList()
      ..sort((a, b) => b.compareTo(a));

    return dayKeys.map((key) {
      final entries = grouped[key] ?? const <SaleRecord>[];
      final dayPayments = paymentsByDay[key] ?? const <HistoryPartialPayment>[];
      final totalPaid =
          _sumPaidOnly(entries) +
          dayPayments.fold<double>(0.0, (total, item) => total + item.amount);
      return SalesDayGroup(
        label: key,
        entries: entries,
        partialPayments: dayPayments,
        totalPaid: totalPaid,
      );
    }).toList();
  }

  List<HistoryPartialPayment> _collectPartialPayments(
    List<SaleRecord> records,
    DateTimeRange range,
  ) {
    final out = <HistoryPartialPayment>[];
    bool inRange(DateTime value) =>
        !value.isBefore(range.start) && value.isBefore(range.end);

    for (final record in records) {
      if (!record.isDeferred) continue;

      final rawEvents = record.data['payment_events'];
      if (rawEvents is List && rawEvents.isNotEmpty) {
        for (var index = 0; index < rawEvents.length; index++) {
          final entry = rawEvents[index];
          if (entry is! Map) continue;
          final map = entry.cast<String, dynamic>();
          final amount = parseDouble(map['amount']);
          final at = parseOptionalDate(map['at']);
          if (amount <= 0 || at == null) continue;
          if (!inRange(at)) continue;

          final eventId = (map['id'] ?? '').toString().trim();
          out.add(
            HistoryPartialPayment(
              saleId: record.id,
              customerName: record.note,
              amount: amount,
              at: at,
              eventId: eventId.isEmpty ? null : eventId,
              eventIndex: index,
              isFallback: false,
            ),
          );
        }
        continue;
      }

      final fallbackAmount = parseDouble(record.data['last_payment_amount']);
      final fallbackAt = parseOptionalDate(record.data['last_payment_at']);
      if (fallbackAmount > 0 && fallbackAt != null && inRange(fallbackAt)) {
        out.add(
          HistoryPartialPayment(
            saleId: record.id,
            customerName: record.note,
            amount: fallbackAmount,
            at: fallbackAt,
            eventId: null,
            eventIndex: null,
            isFallback: true,
          ),
        );
      }
    }

    return out;
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

  List<SaleRecord> _filterRecordsForRange(
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
    return filtered;
  }

  String _buildCsv(List<SaleRecord> records) {
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln(
      'date_time,title,type,total_price,total_cost,profit,paid,deferred,complimentary,note,id',
    );

    for (final record in records) {
      final profit = record.totalPrice - record.totalCost;
      final row = [
        formatDateTime(record.effectiveTime),
        record.titleLine,
        record.type,
        record.totalPrice.toStringAsFixed(2),
        record.totalCost.toStringAsFixed(2),
        profit.toStringAsFixed(2),
        record.isPaid ? '1' : '0',
        record.isDeferred ? '1' : '0',
        record.isComplimentary ? '1' : '0',
        record.note,
        record.id,
      ];
      buffer.writeln(row.map(_escapeCsv).join(','));
    }
    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains('"')) {
      value = value.replaceAll('"', '""');
    }
    if (value.contains(',') || value.contains('\n') || value.contains('\r')) {
      return '"$value"';
    }
    return value;
  }

  Future<File> _writeCsvFile(String csv, DateTimeRange range) async {
    final primaryDir = await _resolveExportDirectory();
    final fallbackDir = await getApplicationDocumentsDirectory();
    final fileName = _buildExportFileName(range);

    try {
      return await _writeUniqueFile(primaryDir, fileName, csv);
    } catch (_) {
      if (primaryDir.path == fallbackDir.path) rethrow;
      return _writeUniqueFile(fallbackDir, fileName, csv);
    }
  }

  Future<File> _writeUniqueFile(
    Directory directory,
    String fileName,
    String contents,
  ) async {
    await directory.create(recursive: true);
    var attempt = 0;
    final dot = fileName.lastIndexOf('.');
    final base = dot == -1 ? fileName : fileName.substring(0, dot);
    final ext = dot == -1 ? '' : fileName.substring(dot);
    File file;
    do {
      final suffix = attempt == 0 ? '' : '_${attempt + 1}';
      final name = '$base$suffix$ext';
      final path = '${directory.path}${Platform.pathSeparator}$name';
      file = File(path);
      attempt++;
    } while (await file.exists());

    await file.writeAsString(contents, encoding: utf8);
    return file;
  }

  String _buildExportFileName(DateTimeRange range) {
    final startLabel = _formatDate(range.start);
    final endLabel = _formatDate(
      range.end.subtract(const Duration(seconds: 1)),
    );
    if (startLabel == endLabel) {
      return 'sales_$startLabel.csv';
    }
    return 'sales_${startLabel}_to_$endLabel.csv';
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<Directory> _resolveExportDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        return downloads;
      }
      final external = await getExternalStorageDirectory();
      if (external != null) return external;
    } else {
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) return downloads;
      } catch (_) {
        // Fall back to documents below.
      }
    }
    return getApplicationDocumentsDirectory();
  }

  @override
  Future<void> close() {
    _realtimeDebounce?.cancel();
    _summaryDebounce?.cancel();
    _createdSub?.cancel();
    _settledSub?.cancel();
    _createdDeferredSub?.cancel();
    _settledDeferredSub?.cancel();
    _paymentSub?.cancel();
    _deferredPaymentSub?.cancel();
    _creditCountSub?.cancel();
    return super.close();
  }
}
