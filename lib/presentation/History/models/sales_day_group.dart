import 'sale_record.dart';

class SalesDayGroup {
  const SalesDayGroup({
    required this.label,
    required this.entries,
    required this.totalPaid,
  });

  final String label;
  final List<SaleRecord> entries;
  final double totalPaid;
}
