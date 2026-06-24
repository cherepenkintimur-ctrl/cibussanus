import '../database/db_service.dart';
import '../models/order.dart';
import '../models/order_item.dart';

class OrderRepository {
  const OrderRepository();

  Future<int> create({
    required String orderNumber,
    DateTime? orderDate,
    String? paymentMethod,
    String? notes,
    required List<OrderItem> items,
  }) async {
    return DbService.instance.transaction<int>(() async {
      final inserted = await DbService.instance.query(
        '''
        INSERT INTO orders (order_number, order_date, total_amount, payment_method, notes)
        VALUES (@order_number, COALESCE(@order_date, NOW()), 0, @payment_method, @notes)
        RETURNING id
        ''',
        parameters: {
          'order_number': orderNumber,
          'order_date': orderDate,
          'payment_method': paymentMethod,
          'notes': notes,
        },
      );

      final orderId = (inserted.first['id'] as num).toInt();

      await _insertItems(orderId, items);
      await recalculateTotal(orderId);

      return orderId;
    });
  }

  Future<int> updateWithItems({
    required int id,
    required String orderNumber,
    DateTime? orderDate,
    String? paymentMethod,
    String? notes,
    required List<OrderItem> items,
  }) async {
    return DbService.instance.transaction<int>(() async {
      await DbService.instance.query(
        '''
        UPDATE orders
        SET order_number = @order_number,
            order_date = COALESCE(@order_date, order_date),
            payment_method = @payment_method,
            notes = @notes
        WHERE id = @id
        ''',
        parameters: {
          'id': id,
          'order_number': orderNumber,
          'order_date': orderDate,
          'payment_method': paymentMethod,
          'notes': notes,
        },
      );

      await DbService.instance.query(
        'DELETE FROM order_items WHERE order_id = @order_id',
        parameters: {'order_id': id},
      );

      await _insertItems(id, items);
      await recalculateTotal(id);

      return id;
    });
  }

  Future<void> _insertItems(int orderId, List<OrderItem> items) async {
    for (final item in items) {
      await DbService.instance.query(
        '''
        INSERT INTO order_items (order_id, dish_id, quantity, unit_price)
        VALUES (@order_id, @dish_id, @quantity, @unit_price)
        ''',
        parameters: {
          'order_id': orderId,
          'dish_id': item.dishId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
        },
      );
    }
  }

  Future<List<OrderModel>> getAll() async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, order_number, order_date, total_amount, payment_method, notes
      FROM orders
      ORDER BY order_date DESC, id DESC
      ''',
    );
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<OrderModel?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      '''
      SELECT id, order_number, order_date, total_amount, payment_method, notes
      FROM orders
      WHERE id = @id
      ''',
      parameters: {'id': id},
    );
    return row == null ? null : OrderModel.fromMap(row);
  }

  Future<List<Map<String, dynamic>>> getDetails(int orderId) async {
    return DbService.instance.query(
      '''
      SELECT
          oi.id,
          oi.order_id,
          oi.dish_id,
          d.name AS dish_name,
          oi.quantity,
          oi.unit_price,
          oi.line_total
      FROM order_items oi
      JOIN dishes d ON d.id = oi.dish_id
      WHERE oi.order_id = @order_id
      ORDER BY oi.id
      ''',
      parameters: {'order_id': orderId},
    );
  }

  Future<int> update({
    required int id,
    required String orderNumber,
    DateTime? orderDate,
    String? paymentMethod,
    String? notes,
  }) async {
    final rows = await DbService.instance.query(
      '''
      UPDATE orders
      SET order_number = @order_number,
          order_date = COALESCE(@order_date, order_date),
          payment_method = @payment_method,
          notes = @notes
      WHERE id = @id
      RETURNING id
      ''',
      parameters: {
        'id': id,
        'order_number': orderNumber,
        'order_date': orderDate,
        'payment_method': paymentMethod,
        'notes': notes,
      },
    );
    return rows.length;
  }

  Future<int> delete(int id) async {
    final rows = await DbService.instance.query(
      'DELETE FROM orders WHERE id = @id RETURNING id',
      parameters: {'id': id},
    );
    return rows.length;
  }

  Future<double> recalculateTotal(int orderId) async {
    await DbService.instance.query(
      'SELECT recalculate_order_total(@order_id)',
      parameters: {'order_id': orderId},
    );

    final row = await DbService.instance.queryOne(
      'SELECT total_amount FROM orders WHERE id = @id',
      parameters: {'id': orderId},
    );

    return row == null ? 0.0 : (row['total_amount'] as num).toDouble();
  }
}