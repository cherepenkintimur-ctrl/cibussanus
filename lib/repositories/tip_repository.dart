import '../database/db_service.dart';
import '../models/tip.dart';

class TipRepository {
  const TipRepository();

  Future<int> create(Tip tip) async {
    return DbService.instance.insert('tips', tip.toMap()..remove('id'));
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('tips', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tip>> getAll() async {
    final rows = await DbService.instance.query('''
      SELECT t.*, w.name as waiter_name
      FROM tips t
      LEFT JOIN waiters w ON w.id = t.waiter_id
      ORDER BY t.created_at DESC
    ''');
    return rows.map(Tip.fromMap).toList();
  }

  Future<List<Tip>> getByWaiter(int waiterId) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM tips WHERE waiter_id = ? ORDER BY created_at DESC',
      arguments: [waiterId],
    );
    return rows.map(Tip.fromMap).toList();
  }

  Future<double> getTotalTipsByWaiter(int waiterId, {DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final row = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM tips WHERE waiter_id = ? AND created_at >= ? AND created_at < ?
      ''',
      arguments: [waiterId, start.toIso8601String(), end.toIso8601String()],
    );
    return (row?['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalTipsAll({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final row = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM tips WHERE created_at >= ? AND created_at < ?
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );
    return (row?['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getTipsByWaiterReport({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    return DbService.instance.query(
      '''
      SELECT
        w.id,
        w.name,
        COUNT(t.id) as tips_count,
        COALESCE(SUM(t.amount), 0) as total_tips,
        COALESCE(AVG(t.amount), 0) as avg_tip,
        COALESCE(MAX(t.amount), 0) as max_tip
      FROM waiters w
      LEFT JOIN tips t ON t.waiter_id = w.id AND t.created_at >= ? AND t.created_at < ?
      WHERE w.is_active = 1
      GROUP BY w.id, w.name
      ORDER BY total_tips DESC
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> getDailyTipsTrend({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    return DbService.instance.query(
      '''
      SELECT
        DATE(created_at) as date,
        COUNT(*) as tips_count,
        COALESCE(SUM(amount), 0) as total_tips,
        COALESCE(AVG(amount), 0) as avg_tip
      FROM tips
      WHERE created_at >= ? AND created_at < ?
      GROUP BY DATE(created_at)
      ORDER BY date
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );
  }
}
