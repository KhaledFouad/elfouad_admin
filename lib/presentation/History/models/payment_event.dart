import '../utils/sale_utils.dart';

class PaymentEvent {
  PaymentEvent({
    required this.amount,
    required this.at,
  });

  final double amount;
  final DateTime at;

  static PaymentEvent fromMap(Map<String, dynamic> map) {
    return PaymentEvent(
      amount: parseDouble(map['amount']),
      at: parseDate(map['at']),
    );
  }
}
