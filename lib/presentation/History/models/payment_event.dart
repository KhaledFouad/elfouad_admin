import '../utils/sale_utils.dart';

class PaymentEvent {
  PaymentEvent({this.id = '', required this.amount, required this.at});

  final String id;
  final double amount;
  final DateTime at;

  static PaymentEvent fromMap(Map<String, dynamic> map) {
    return PaymentEvent(
      id: (map['id'] ?? '').toString(),
      amount: parseDouble(map['amount']),
      at: parseDate(map['at']),
    );
  }
}
