import 'converters.dart';

class SplitPayment {
  final int? id;
  final int? orderId;
  final String paymentMethod;
  final double amount;
  final DateTime? createdAt;

  const SplitPayment({
    this.id,
    this.orderId,
    required this.paymentMethod,
    required this.amount,
    this.createdAt,
  });

  factory SplitPayment.fromMap(Map<String, dynamic> map) {
    return SplitPayment(
      id: parseInt(map['id']),
      orderId: parseInt(map['order_id']),
      paymentMethod: (map['payment_method'] ?? '').toString(),
      amount: parseDouble(map['amount']),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      'payment_method': paymentMethod,
      'amount': amount,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
