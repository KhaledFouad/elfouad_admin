import 'sale_record.dart';
import 'history_partial_payment.dart';

class SalesDayGroup {
  const SalesDayGroup({
    required this.label,
    required this.entries,
    required this.partialPayments,
    required this.totalPaid,
  });

  final String label;
  final List<SaleRecord> entries;
  final List<HistoryPartialPayment> partialPayments;
  final double totalPaid;
}
