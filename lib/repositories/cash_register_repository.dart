import '../database/db_service.dart';
import '../models/cash_register.dart';

class CashRegisterRepository {
  const CashRegisterRepository();

  Future<int> create(CashRegister register) async {
    return DbService.instance.insert('cash_registers', register.toMap()..remove('id'));
  }

  Future<int> update(CashRegister register) async {
    if (register.id == null) throw ArgumentError('CashRegister id is required');
    return DbService.instance.update(
      'cash_registers',
      register.toMap(),
      where: 'id = ?',
      whereArgs: [register.id],
    );
  }

  Future<CashRegister?> getOpen() async {
    final row = await DbService.instance.queryOne(
      "SELECT * FROM cash_registers WHERE status = 'Открыта' ORDER BY open_time DESC LIMIT 1"
    );
    return row == null ? null : CashRegister.fromMap(row);
  }

  Future<void> closeRegister(int id, {required double closingBalance, String? notes}) async {
    final openRow = await DbService.instance.queryOne(
      'SELECT * FROM cash_registers WHERE id = ?',
      arguments: [id],
    );
    if (openRow == null) return;

    final expected = (openRow['opening_balance'] as num).toDouble() +
                     (openRow['total_cash'] as num).toDouble();
    final discrepancy = closingBalance - expected;

    await DbService.instance.update(
      'cash_registers',
      {
        'close_time': DateTime.now().toIso8601String(),
        'closing_balance': closingBalance,
        'expected_balance': expected,
        'discrepancy': discrepancy,
        'status': 'Закрыта',
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTotals(int id) async {
    final row = await DbService.instance.queryOne(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN payment_method = 'Наличные' THEN total_amount ELSE 0 END), 0) as cash,
        COALESCE(SUM(CASE WHEN payment_method = 'Карта' THEN total_amount ELSE 0 END), 0) as card,
        COALESCE(SUM(CASE WHEN payment_method NOT IN ('Наличные', 'Карта') THEN total_amount ELSE 0 END), 0) as other,
        COUNT(*) as orders_count
      FROM orders WHERE status = 'Оплачен' AND order_date >= (
        SELECT open_time FROM cash_registers WHERE id = ?
      )
      ''',
      arguments: [id],
    );

    if (row != null) {
      await DbService.instance.update(
        'cash_registers',
        {
          'total_cash': row['cash'],
          'total_card': row['card'],
          'total_other': row['other'],
          'total_orders': row['orders_count'],
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<List<CashRegister>> getAll() async {
    final rows = await DbService.instance.query(
      'SELECT * FROM cash_registers ORDER BY open_time DESC'
    );
    return rows.map(CashRegister.fromMap).toList();
  }

  Future<List<CashRegister>> getByPeriod(DateTime start, DateTime end) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM cash_registers WHERE open_time >= ? AND open_time < ? ORDER BY open_time DESC',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map(CashRegister.fromMap).toList();
  }

  Future<Map<String, dynamic>> getZReport(int registerId) async {
    final reg = await DbService.instance.queryOne(
      'SELECT * FROM cash_registers WHERE id = ?',
      arguments: [registerId],
    );
    if (reg == null) return {};

    final paymentBreakdown = await DbService.instance.query(
      '''
      SELECT payment_method, COUNT(*) as count, SUM(total_amount) as total
      FROM orders WHERE status = 'Оплачен' AND order_date >= ? AND order_date <= ?
      GROUP BY payment_method
      ''',
      arguments: [reg['open_time'], reg['close_time'] ?? DateTime.now().toIso8601String()],
    );

    final hourlyBreakdown = await DbService.instance.query(
      '''
      SELECT
        CAST(strftime('%H', order_date) AS INTEGER) as hour,
        COUNT(*) as count,
        SUM(total_amount) as total
      FROM orders WHERE status = 'Оплачен' AND order_date >= ? AND order_date <= ?
      GROUP BY strftime('%H', order_date)
      ORDER BY hour
      ''',
      arguments: [reg['open_time'], reg['close_time'] ?? DateTime.now().toIso8601String()],
    );

    final topDishes = await DbService.instance.query(
      '''
      SELECT d.name, SUM(oi.quantity) as qty, SUM(oi.line_total) as revenue
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN dishes d ON d.id = oi.dish_id
      WHERE o.status = 'Оплачен' AND o.order_date >= ? AND o.order_date <= ?
      GROUP BY d.id, d.name
      ORDER BY revenue DESC LIMIT 5
      ''',
      arguments: [reg['open_time'], reg['close_time'] ?? DateTime.now().toIso8601String()],
    );

    return {
      'register': reg,
      'payment_breakdown': paymentBreakdown,
      'hourly_breakdown': hourlyBreakdown,
      'top_dishes': topDishes,
    };
  }
}
