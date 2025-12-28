import 'sale_record.dart';

class CreditCustomerAccount {
  CreditCustomerAccount({
    required this.name,
    required List<SaleRecord> sales,
  }) : sales = List.unmodifiable(sales);

  final String name;
  final List<SaleRecord> sales;

  double get totalOwed {
    double sum = 0;
    for (final sale in sales) {
      final due = sale.outstandingAmount;
      if (due > 0) {
        sum += due;
      }
    }
    return sum;
  }

  int get unpaidCount {
    int count = 0;
    for (final sale in sales) {
      if (sale.outstandingAmount > 0) {
        count++;
      }
    }
    return count;
  }

  int get paidCount => sales.length - unpaidCount;
}
