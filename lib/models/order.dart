import 'converters.dart';

class OrderModel {
  final int? id;
  final String orderNumber;
  final DateTime? orderDate;
  final double totalAmount;
  final String? paymentMethod;
  final String? notes;
  final int? waiterId;
  final int? tableId;
  final int? discountId;
  final double discountAmount;
  final String status;
  final int? customerId;

  const OrderModel({
    this.id,
    required this.orderNumber,
    this.orderDate,
    required this.totalAmount,
    this.paymentMethod,
    this.notes,
    this.waiterId,
    this.tableId,
    this.discountId,
    this.discountAmount = 0,
    this.status = 'Новый',
    this.customerId,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: parseInt(map['id']),
      orderNumber: (map['order_number'] ?? '').toString(),
      orderDate: parseDateTime(map['order_date']),
      totalAmount: parseDouble(map['total_amount']),
      paymentMethod: map['payment_method']?.toString(),
      notes: map['notes']?.toString(),
      waiterId: parseInt(map['waiter_id']),
      tableId: parseInt(map['table_id']),
      discountId: parseInt(map['discount_id']),
      discountAmount: parseDouble(map['discount_amount']),
      status: (map['status'] ?? 'Новый').toString(),
      customerId: parseInt(map['customer_id']),
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
      'waiter_id': waiterId,
      'table_id': tableId,
      'discount_id': discountId,
      'discount_amount': discountAmount,
      'status': status,
      'customer_id': customerId,
    };
  }

  OrderModel copyWith({
    int? id,
    String? orderNumber,
    DateTime? orderDate,
    double? totalAmount,
    String? paymentMethod,
    String? notes,
    int? waiterId,
    int? tableId,
    int? discountId,
    double? discountAmount,
    String? status,
    int? customerId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      waiterId: waiterId ?? this.waiterId,
      tableId: tableId ?? this.tableId,
      discountId: discountId ?? this.discountId,
      discountAmount: discountAmount ?? this.discountAmount,
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
    );
  }

  double get finalAmount => totalAmount - discountAmount;
}
