import '../database/db_service.dart';
import '../models/waiter_schedule.dart';

class WaiterScheduleRepository {
  const WaiterScheduleRepository();

  Future<int> create(WaiterSchedule schedule) async {
    return DbService.instance.insert('waiter_schedules', schedule.toMap()..remove('id'));
  }

  Future<int> update(WaiterSchedule schedule) async {
    if (schedule.id == null) throw ArgumentError('Schedule id is required');
    return DbService.instance.update(
      'waiter_schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('waiter_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WaiterSchedule>> getByDateRange(DateTime start, DateTime end) async {
    final rows = await DbService.instance.query('''
      SELECT ws.*, w.name as waiter_name
      FROM waiter_schedules ws
      LEFT JOIN waiters w ON w.id = ws.waiter_id
      WHERE ws.date >= ? AND ws.date < ?
      ORDER BY ws.date, ws.start_time
    ''', arguments: [start.toIso8601String(), end.toIso8601String()]);
    return rows.map(WaiterSchedule.fromMap).toList();
  }

  Future<List<WaiterSchedule>> getWeekSchedule(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return getByDateRange(weekStart, weekEnd);
  }

  Future<void> updateStatus(int id, String status) async {
    await DbService.instance.update(
      'waiter_schedules',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> getScheduleStats(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final rows = await DbService.instance.query(
      '''
      SELECT
        w.id,
        w.name,
        COUNT(ws.id) as shift_count,
        COALESCE(SUM(
          (CAST(substr(ws.end_time, 1, 2) AS INTEGER) + CAST(substr(ws.end_time, 4, 2) AS REAL) / 60) -
          (CAST(substr(ws.start_time, 1, 2) AS INTEGER) + CAST(substr(ws.start_time, 4, 2) AS REAL) / 60)
        ), 0) as total_hours
      FROM waiters w
      LEFT JOIN waiter_schedules ws ON ws.waiter_id = w.id AND ws.date >= ? AND ws.date < ?
      WHERE w.is_active = 1
      GROUP BY w.id, w.name
      ORDER BY total_hours DESC
      ''',
      arguments: [weekStart.toIso8601String(), weekEnd.toIso8601String()],
    );
    return {'by_waiter': rows};
  }
}
