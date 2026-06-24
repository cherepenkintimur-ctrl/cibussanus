import 'converters.dart';

class OrderModel {
  final int? id;
  final String orderNumber;
  final DateTime? orderDate;
  final double totalAmount;
  final String? paymentMethod;
  final String? notes;

  const OrderModel({
    this.id,
    required this.orderNumber,
    this.orderDate,
    required this.totalAmount,
    this.paymentMethod,
    this.notes,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: parseInt(map['id']),
      orderNumber: (map['order_number'] ?? '').toString(),
      orderDate: parseDateTime(map['order_date']),
      totalAmount: parseDouble(map['total_amount']),
      paymentMethod: map['payment_method']?.toString(),
      notes: map['notes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_number': orderNumber,
      if (orderDate != null) 'order_date': orderDate,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'notes': notes,
    };
  }

  OrderModel copyWith({
    int? id,
    String? orderNumber,
    DateTime? orderDate,
    double? totalAmount,
    String? paymentMethod,
    String? notes,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
    );
  }
}
