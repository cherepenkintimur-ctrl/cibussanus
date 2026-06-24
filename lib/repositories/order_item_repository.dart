import '../database/db_service.dart';
import '../models/order_item.dart';

class OrderItemRepository {
  const OrderItemRepository();

  Future<int> create(OrderItem item) async {
    final rows = await DbService.instance.query(
      '''
      INSERT INTO order_items (order_id, dish_id, quantity, unit_price)
      VALUES (@order_id, @dish_id, @quantity, @unit_price)
      RETURNING id
      ''',
      parameters: {
        'order_id': item.orderId,
        'dish_id': item.dishId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
      },
    );
    return (rows.first['id'] as num).toInt();
  }

  Future<List<OrderItem>> getByOrderId(int orderId) async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, order_id, dish_id, quantity, unit_price, line_total
      FROM order_items
      WHERE order_id = @order_id
      ORDER BY id
      ''',
      parameters: {'order_id': orderId},
    );
    return rows.map(OrderItem.fromMap).toList();
  }

  Future<OrderItem?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      '''
      SELECT id, order_id, dish_id, quantity, unit_price, line_total
      FROM order_items
      WHERE id = @id
      ''',
      parameters: {'id': id},
    );
    return row == null ? null : OrderItem.fromMap(row);
  }

  Future<int> update(OrderItem item) async {
    if (item.id == null) {
      throw ArgumentError('Order item id is required for update');
    }

    final rows = await DbService.instance.query(
      '''
      UPDATE order_items
      SET order_id = @order_id,
          dish_id = @dish_id,
          quantity = @quantity,
          unit_price = @unit_price
      WHERE id = @id
      RETURNING id
      ''',
      parameters: {
        'id': item.id,
        'order_id': item.orderId,
        'dish_id': item.dishId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
      },
    );
    return rows.length;
  }

  Future<int> delete(int id) async {
    final rows = await DbService.instance.query(
      'DELETE FROM order_items WHERE id = @id RETURNING id',
      parameters: {'id': id},
    );
    return rows.length;
  }
}
