class HistoryPartialPayment {
  const HistoryPartialPayment({
    required this.saleId,
    required this.customerName,
    required this.amount,
    required this.at,
    this.eventId,
    this.eventIndex,
    this.isFallback = false,
  });

  final String saleId;
  final String customerName;
  final double amount;
  final DateTime at;
  final String? eventId;
  final int? eventIndex;
  final bool isFallback;
}
