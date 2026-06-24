import 'converters.dart';

class OrderItem {
  final int? id;
  final int orderId;
  final int dishId;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const OrderItem({
    this.id,
    required this.orderId,
    required this.dishId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: parseInt(map['id']),
      orderId: parseInt(map['order_id']) ?? 0,
      dishId: parseInt(map['dish_id']) ?? 0,
      quantity: parseInt(map['quantity']) ?? 0,
      unitPrice: parseDouble(map['unit_price']),
      lineTotal: parseDouble(map['line_total']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'dish_id': dishId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': lineTotal,
    };
  }

  OrderItem copyWith({
    int? id,
    int? orderId,
    int? dishId,
    int? quantity,
    double? unitPrice,
    double? lineTotal,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      dishId: dishId ?? this.dishId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }
}
