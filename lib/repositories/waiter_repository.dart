import '../database/db_service.dart';
import '../models/waiter.dart';

class WaiterRepository {
  const WaiterRepository();

  Future<int> create(Waiter waiter) async {
    return DbService.instance.insert('waiters', waiter.toMap()..remove('id'));
  }

  Future<int> update(Waiter waiter) async {
    if (waiter.id == null) throw ArgumentError('Waiter id is required');
    return DbService.instance.update(
      'waiters',
      waiter.toMap(),
      where: 'id = ?',
      whereArgs: [waiter.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('waiters', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Waiter>> getAll({bool onlyActive = false}) async {
    final where = onlyActive ? 'WHERE is_active = 1' : '';
    final rows = await DbService.instance.query(
      'SELECT * FROM waiters $where ORDER BY name',
    );
    return rows.map(Waiter.fromMap).toList();
  }

  Future<List<Waiter>> search(String keyword) async {
    final q = keyword.trim();
    final rows = await DbService.instance.query(
      'SELECT * FROM waiters WHERE name LIKE ? OR role LIKE ? OR COALESCE(phone, '') LIKE ? OR COALESCE(email, '') LIKE ? ORDER BY name',
      arguments: ['%$q%', '%$q%', '%$q%', '%$q%'],
    );
    return rows.map(Waiter.fromMap).toList();
  }

  Future<Waiter?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      'SELECT * FROM waiters WHERE id = ?',
      arguments: [id],
    );
    return row == null ? null : Waiter.fromMap(row);
  }

  Future<void> toggleActive(int id) async {
    await DbService.instance.execute(
      'UPDATE waiters SET is_active = CASE WHEN is_active = 1 THEN 0 ELSE 1 END WHERE id = ?',
      arguments: [id],
    );
  }

  Future<Map<String, dynamic>> getWaiterStats(int waiterId, {DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final revenueRow = await DbService.instance.queryOne(
      '''
      SELECT COUNT(*) as order_count, COALESCE(SUM(total_amount), 0) as total_revenue
      FROM orders WHERE waiter_id = ? AND order_date >= ? AND order_date < ?
      ''',
      arguments: [waiterId, start.toIso8601String(), end.toIso8601String()],
    );

    final tipRow = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(SUM(amount), 0) as total_tips
      FROM tips WHERE waiter_id = ? AND created_at >= ? AND created_at < ?
      ''',
      arguments: [waiterId, start.toIso8601String(), end.toIso8601String()],
    );

    final avgRow = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(AVG(total_amount), 0) as avg_check
      FROM orders WHERE waiter_id = ? AND order_date >= ? AND order_date < ?
      ''',
      arguments: [waiterId, start.toIso8601String(), end.toIso8601String()],
    );

    return {
      'order_count': revenueRow?['order_count'] ?? 0,
      'total_revenue': revenueRow?['total_revenue'] ?? 0.0,
      'total_tips': tipRow?['total_tips'] ?? 0.0,
      'avg_check': avgRow?['avg_check'] ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getWaitersLeaderboard({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    return DbService.instance.query(
      '''
      SELECT
        w.id,
        w.name,
        w.role,
        COUNT(o.id) as order_count,
        COALESCE(SUM(o.total_amount), 0) as total_revenue,
        COALESCE(AVG(o.total_amount), 0) as avg_check,
        (SELECT COALESCE(SUM(t.amount), 0) FROM tips t WHERE t.waiter_id = w.id AND t.created_at >= ? AND t.created_at < ?) as total_tips
      FROM waiters w
      LEFT JOIN orders o ON o.waiter_id = w.id AND o.order_date >= ? AND o.order_date < ?
      WHERE w.is_active = 1
      GROUP BY w.id, w.name, w.role
      ORDER BY total_revenue DESC
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String(), start.toIso8601String(), end.toIso8601String()],
    );
  }
}
