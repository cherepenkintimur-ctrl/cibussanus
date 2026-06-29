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
    int? waiterId,
    int? tableId,
    int? discountId,
    double discountAmount = 0,
    String status = 'Новый',
    required List<OrderItem> items,
  }) async {
    return DbService.instance.transaction<int>(() async {
      final orderId = await DbService.instance.insert('orders', {
        'order_number': orderNumber,
        'order_date': orderDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'total_amount': 0,
        'payment_method': paymentMethod,
        'notes': notes,
        'waiter_id': waiterId,
        'table_id': tableId,
        'discount_id': discountId,
        'discount_amount': discountAmount,
        'status': status,
      });

      await _insertItems(orderId, items);
      await recalculateTotal(orderId);

      if (tableId != null) {
        await DbService.instance.update(
          'restaurant_tables',
          {'status': 'Занят'},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }

      if (discountId != null) {
        await DbService.instance.execute(
          'UPDATE discounts SET usage_count = usage_count + 1 WHERE id = ?',
          arguments: [discountId],
        );
      }

      return orderId;
    });
  }

  Future<int> updateWithItems({
    required int id,
    required String orderNumber,
    DateTime? orderDate,
    String? paymentMethod,
    String? notes,
    int? waiterId,
    int? tableId,
    int? discountId,
    double discountAmount = 0,
    String status = 'Новый',
    required List<OrderItem> items,
  }) async {
    return DbService.instance.transaction<int>(() async {
      final oldOrder = await DbService.instance.queryOne(
        'SELECT table_id FROM orders WHERE id = ?',
        arguments: [id],
      );

      await DbService.instance.update(
        'orders',
        {
          'order_number': orderNumber,
          if (orderDate != null) 'order_date': orderDate.toIso8601String(),
          'payment_method': paymentMethod,
          'notes': notes,
          'waiter_id': waiterId,
          'table_id': tableId,
          'discount_id': discountId,
          'discount_amount': discountAmount,
          'status': status,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await DbService.instance.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [id],
      );

      await _insertItems(id, items);
      await recalculateTotal(id);

      if (oldOrder != null && oldOrder['table_id'] != null && oldOrder['table_id'] != tableId) {
        final stillUsed = await DbService.instance.queryOne(
          'SELECT COUNT(*) as cnt FROM orders WHERE table_id = ? AND id != ? AND status != \'Оплачен\'',
          arguments: [oldOrder['table_id'], id],
        );
        if (stillUsed == null || (stillUsed['cnt'] as int) == 0) {
          await DbService.instance.update(
            'restaurant_tables',
            {'status': 'Свободен'},
            where: 'id = ?',
            whereArgs: [oldOrder['table_id']],
          );
        }
      }

      if (tableId != null) {
        await DbService.instance.update(
          'restaurant_tables',
          {'status': 'Занят'},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }

      return id;
    });
  }

  Future<void> _insertItems(int orderId, List<OrderItem> items) async {
    for (final item in items) {
      final lineTotal = item.quantity * item.unitPrice;
      await DbService.instance.insert('order_items', {
        'order_id': orderId,
        'dish_id': item.dishId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'line_total': lineTotal,
      });
    }
  }

  Future<List<OrderModel>> getAll() async {
    final rows = await DbService.instance.query('''
      SELECT o.*,
             w.name as waiter_name,
             t.table_number
      FROM orders o
      LEFT JOIN waiters w ON w.id = o.waiter_id
      LEFT JOIN restaurant_tables t ON t.id = o.table_id
      ORDER BY o.order_date DESC, o.id DESC
    ''');
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<List<OrderModel>> search(String keyword) async {
    final q = keyword.trim();
    final rows = await DbService.instance.query('''
      SELECT o.*,
             w.name as waiter_name,
             t.table_number
      FROM orders o
      LEFT JOIN waiters w ON w.id = o.waiter_id
      LEFT JOIN restaurant_tables t ON t.id = o.table_id
      WHERE o.order_number LIKE ? OR o.status LIKE ? OR o.payment_method LIKE ? OR COALESCE(o.notes, '') LIKE ?
      ORDER BY o.order_date DESC, o.id DESC
    ''', arguments: ['%$q%', '%$q%', '%$q%', '%$q%']);
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<OrderModel?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      'SELECT * FROM orders WHERE id = ?',
      arguments: [id],
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
          oi.line_total,
          d.cost_price
      FROM order_items oi
      JOIN dishes d ON d.id = oi.dish_id
      WHERE oi.order_id = ?
      ORDER BY oi.id
      ''',
      arguments: [orderId],
    );
  }

  Future<int> update({
    required int id,
    required String orderNumber,
    DateTime? orderDate,
    String? paymentMethod,
    String? notes,
  }) async {
    return DbService.instance.update(
      'orders',
      {
        'order_number': orderNumber,
        if (orderDate != null) 'order_date': orderDate.toIso8601String(),
        'payment_method': paymentMethod,
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateStatus(int id, String status) async {
    await DbService.instance.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (status == 'Оплачен') {
      final order = await DbService.instance.queryOne(
        'SELECT table_id FROM orders WHERE id = ?',
        arguments: [id],
      );
      if (order != null && order['table_id'] != null) {
        final tableId = order['table_id'];
        final otherActive = await DbService.instance.queryOne(
          'SELECT COUNT(*) as cnt FROM orders WHERE table_id = ? AND id != ? AND status NOT IN (\'Оплачен\', \'Отменён\')',
          arguments: [tableId, id],
        );
        if (otherActive == null || (otherActive['cnt'] as int) == 0) {
          await DbService.instance.update(
            'restaurant_tables',
            {'status': 'Свободен'},
            where: 'id = ?',
            whereArgs: [tableId],
          );
        }
      }
    }
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> recalculateTotal(int orderId) async {
    final row = await DbService.instance.queryOne(
      'SELECT COALESCE(SUM(line_total), 0) AS total FROM order_items WHERE order_id = ?',
      arguments: [orderId],
    );

    final total = row == null ? 0.0 : (row['total'] as num).toDouble();

    await DbService.instance.update(
      'orders',
      {'total_amount': total},
      where: 'id = ?',
      whereArgs: [orderId],
    );

    return total;
  }

  Future<List<OrderModel>> getByStatus(String status) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM orders WHERE status = ? ORDER BY order_date DESC',
      arguments: [status],
    );
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<List<OrderModel>> getByCustomerId(int customerId) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM orders WHERE customer_id = ? ORDER BY order_date DESC LIMIT 5',
      arguments: [customerId],
    );
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<List<OrderModel>> getKitchenOrders() async {
    final rows = await DbService.instance.query('''
      SELECT o.*, w.name as waiter_name, t.table_number
      FROM orders o
      LEFT JOIN waiters w ON w.id = o.waiter_id
      LEFT JOIN restaurant_tables t ON t.id = o.table_id
      WHERE o.status IN ('Новый', 'Готовится')
      ORDER BY
        CASE o.status
          WHEN 'Новый' THEN 0
          WHEN 'Готовится' THEN 1
          ELSE 2
        END,
        o.order_date ASC
    ''');
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getOrderItemsForKitchen(int orderId) async {
    return DbService.instance.query(
      '''
      SELECT d.name as dish_name, oi.quantity, oi.unit_price, oi.line_total
      FROM order_items oi
      JOIN dishes d ON d.id = oi.dish_id
      WHERE oi.order_id = ?
      ''',
      arguments: [orderId],
    );
  }

  Future<Map<int, List<Map<String, dynamic>>>> getAllDetailsBatch() async {
    final rows = await DbService.instance.query('''
      SELECT
          oi.order_id,
          oi.id,
          oi.dish_id,
          d.name AS dish_name,
          oi.quantity,
          oi.unit_price,
          oi.line_total,
          d.cost_price
      FROM order_items oi
      JOIN dishes d ON d.id = oi.dish_id
      ORDER BY oi.order_id, oi.id
    ''');
    final map = <int, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final orderId = row['order_id'] as int;
      map.putIfAbsent(orderId, () => []).add(row);
    }
    return map;
  }
}
