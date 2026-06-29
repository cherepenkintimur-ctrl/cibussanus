import '../database/db_service.dart';
import '../models/shift.dart';

class ShiftRepository {
  const ShiftRepository();

  Future<int> create(Shift shift) async {
    return DbService.instance.insert('shifts', shift.toMap()..remove('id'));
  }

  Future<int> update(Shift shift) async {
    if (shift.id == null) throw ArgumentError('Shift id is required');
    return DbService.instance.update(
      'shifts',
      shift.toMap(),
      where: 'id = ?',
      whereArgs: [shift.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('shifts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Shift>> getAll() async {
    final rows = await DbService.instance.query('''
      SELECT s.*, w.name as waiter_name
      FROM shifts s
      LEFT JOIN waiters w ON w.id = s.waiter_id
      ORDER BY s.start_time DESC
    ''');
    return rows.map(Shift.fromMap).toList();
  }

  Future<List<Shift>> getActive() async {
    final rows = await DbService.instance.query('''
      SELECT s.*, w.name as waiter_name
      FROM shifts s
      LEFT JOIN waiters w ON w.id = s.waiter_id
      WHERE s.status = 'Активна'
      ORDER BY s.start_time DESC
    ''');
    return rows.map(Shift.fromMap).toList();
  }

  Future<void> endShift(int shiftId) async {
    await DbService.instance.update(
      'shifts',
      {
        'end_time': DateTime.now().toIso8601String(),
        'status': 'Завершена',
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  Future<List<Shift>> getByWaiter(int waiterId) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM shifts WHERE waiter_id = ? ORDER BY start_time DESC',
      arguments: [waiterId],
    );
    return rows.map(Shift.fromMap).toList();
  }

  Future<List<Shift>> getByDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day).toIso8601String();
    final dayEnd = DateTime(date.year, date.month, date.day + 1).toIso8601String();
    final rows = await DbService.instance.query('''
      SELECT s.*, w.name as waiter_name
      FROM shifts s
      LEFT JOIN waiters w ON w.id = s.waiter_id
      WHERE s.start_time >= ? AND s.start_time < ?
      ORDER BY s.start_time ASC
    ''', arguments: [dayStart, dayEnd]);
    return rows.map(Shift.fromMap).toList();
  }

  Future<Map<String, dynamic>> getShiftStats({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final rows = await DbService.instance.query(
      '''
      SELECT
        w.id,
        w.name,
        COUNT(s.id) as shift_count,
        COALESCE(SUM(
          CASE WHEN s.end_time IS NOT NULL
          THEN (julianday(s.end_time) - julianday(s.start_time)) * 24
          ELSE 0 END
        ), 0) as total_hours
      FROM waiters w
      LEFT JOIN shifts s ON s.waiter_id = w.id AND s.start_time >= ? AND s.start_time < ?
      WHERE w.is_active = 1
      GROUP BY w.id, w.name
      ORDER BY total_hours DESC
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    return {'by_waiter': rows};
  }
}
