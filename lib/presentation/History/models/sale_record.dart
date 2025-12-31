import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/sale_utils.dart';
import 'sale_component.dart';
import 'payment_event.dart';

class SaleRecord {
  SaleRecord(this.snapshot)
      : data = snapshot.data(),
        id = snapshot.id;

  final QueryDocumentSnapshot<Map<String, dynamic>> snapshot;
  final Map<String, dynamic> data;
  final String id;

  DateTime get createdAt => parseDate(data['created_at']);
  DateTime? get settledAt => parseOptionalDate(data['settled_at']);

  bool get isComplimentary => (data['is_complimentary'] ?? false) == true;

  bool get isDeferred =>
      (data['is_deferred'] ?? data['is_credit'] ?? false) == true;

  bool get isPaid => (data['paid'] ?? (!isDeferred)) == true;

  double get totalPrice => parseDouble(data['total_price']);
  double get totalCost => parseDouble(data['total_cost']);
  double get dueAmount => parseDouble(data['due_amount']);

  String get note => (data['note'] ?? '').toString().trim();

  String get type => (data['type'] ?? detectSaleType(data)).toString();

  DateTime get effectiveTime => computeEffectiveTime(
        createdAt: createdAt,
        settledAt: settledAt,
        isDeferred: isDeferred,
        isPaid: isPaid,
      );

  bool get usesSettledTime =>
      !isSameMinute(effectiveTime, createdAt);

  List<SaleComponent> get components => extractComponents(data, type);

  List<PaymentEvent> get paymentEvents {
    final raw = data['payment_events'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => PaymentEvent.fromMap(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  String get titleLine => buildTitleLine(data, type);

  String get displayTime =>
      (isDeferred && isPaid) ? formatTime(createdAt) : formatTime(effectiveTime);

  String get originalDateTimeLabel => formatDateTime(createdAt);

  bool get canSettle => isDeferred && !isPaid && outstandingAmount > 0;

  double get outstandingAmount {
    if (dueAmount > 0) {
      if (totalPrice > 0 && dueAmount > totalPrice) {
        return totalPrice;
      }
      return dueAmount;
    }
    if (isDeferred && !isPaid) {
      if (paymentEvents.isNotEmpty && totalPrice > 0) {
        final paid = paymentEvents.fold<double>(
          0.0,
          (total, event) => total + event.amount,
        );
        final remaining = totalPrice - paid;
        return remaining > 0 ? remaining : 0.0;
      }
      return totalPrice;
    }
    return 0.0;
  }
}
