import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/sale_record.dart';
import '../models/sales_day_group.dart';
import '../models/credit_account.dart';
import '../models/history_summary.dart';
import '../utils/sale_utils.dart';

class SalesHistoryState extends Equatable {
  static const _unset = Object();

  const SalesHistoryState({
    required this.groups,
    required this.range,
    required this.allRecords,
    required this.fullTotalsByDay,
    required this.isLoadingFirst,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isRangeTotalLoading,
    required this.summary,
    required this.summaryByDay,
    required this.isSummaryLoading,
    required this.creditAccounts,
    required this.isCreditLoading,
    required this.creditUnpaidCount,
    required this.isCreditCountLoading,
    this.customRange,
  });

  factory SalesHistoryState.initial() => SalesHistoryState(
        groups: const [],
        range: defaultSalesRange(),
        allRecords: const [],
        fullTotalsByDay: const {},
        isLoadingFirst: true,
        isLoadingMore: false,
        hasMore: true,
        isRangeTotalLoading: true,
        summary: null,
        summaryByDay: const {},
        isSummaryLoading: false,
        creditAccounts: const [],
        isCreditLoading: false,
        creditUnpaidCount: 0,
        isCreditCountLoading: false,
        customRange: null,
      );

  final List<SalesDayGroup> groups;
  final DateTimeRange range;
  final List<SaleRecord> allRecords;
  final Map<String, double> fullTotalsByDay;
  final bool isLoadingFirst;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isRangeTotalLoading;
  final HistorySummary? summary;
  final Map<String, HistorySummary> summaryByDay;
  final bool isSummaryLoading;
  final List<CreditCustomerAccount> creditAccounts;
  final bool isCreditLoading;
  final int creditUnpaidCount;
  final bool isCreditCountLoading;
  final DateTimeRange? customRange;

  bool get isEmpty => allRecords.isEmpty;
  bool get isFiltered => customRange != null;

  SalesHistoryState copyWith({
    List<SalesDayGroup>? groups,
    DateTimeRange? range,
    List<SaleRecord>? allRecords,
    Map<String, double>? fullTotalsByDay,
    bool? isLoadingFirst,
    bool? isLoadingMore,
    bool? hasMore,
    bool? isRangeTotalLoading,
    Object? summary = _unset,
    Map<String, HistorySummary>? summaryByDay,
    bool? isSummaryLoading,
    List<CreditCustomerAccount>? creditAccounts,
    bool? isCreditLoading,
    int? creditUnpaidCount,
    bool? isCreditCountLoading,
    Object? customRange = _unset,
  }) {
    return SalesHistoryState(
      groups: groups ?? this.groups,
      range: range ?? this.range,
      allRecords: allRecords ?? this.allRecords,
      fullTotalsByDay: fullTotalsByDay ?? this.fullTotalsByDay,
      isLoadingFirst: isLoadingFirst ?? this.isLoadingFirst,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      isRangeTotalLoading:
          isRangeTotalLoading ?? this.isRangeTotalLoading,
      summary: identical(summary, _unset)
          ? this.summary
          : summary as HistorySummary?,
      summaryByDay: summaryByDay ?? this.summaryByDay,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      creditAccounts: creditAccounts ?? this.creditAccounts,
      isCreditLoading: isCreditLoading ?? this.isCreditLoading,
      creditUnpaidCount: creditUnpaidCount ?? this.creditUnpaidCount,
      isCreditCountLoading:
          isCreditCountLoading ?? this.isCreditCountLoading,
      customRange: identical(customRange, _unset)
          ? this.customRange
          : customRange as DateTimeRange?,
    );
  }

  @override
  List<Object?> get props => [
        groups,
        range,
        allRecords,
        fullTotalsByDay,
        isLoadingFirst,
        isLoadingMore,
        hasMore,
        isRangeTotalLoading,
        summary,
        summaryByDay,
        isSummaryLoading,
        creditAccounts,
        isCreditLoading,
        creditUnpaidCount,
        isCreditCountLoading,
        customRange,
      ];
}
