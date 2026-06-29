import 'converters.dart';

class Tip {
  final int? id;
  final int? orderId;
  final int? waiterId;
  final double amount;
  final DateTime? createdAt;

  const Tip({
    this.id,
    this.orderId,
    this.waiterId,
    required this.amount,
    this.createdAt,
  });

  factory Tip.fromMap(Map<String, dynamic> map) {
    return Tip(
      id: parseInt(map['id']),
      orderId: parseInt(map['order_id']),
      waiterId: parseInt(map['waiter_id']),
      amount: parseDouble(map['amount']),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (waiterId != null) 'waiter_id': waiterId,
      'amount': amount,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Tip copyWith({
    int? id,
    int? orderId,
    int? waiterId,
    double? amount,
    DateTime? createdAt,
  }) {
    return Tip(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      waiterId: waiterId ?? this.waiterId,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
