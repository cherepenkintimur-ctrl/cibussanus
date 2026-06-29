import '../database/db_service.dart';
import '../models/reservation.dart';

class ReservationRepository {
  const ReservationRepository();

  Future<int> create(Reservation reservation) async {
    return DbService.instance.insert('reservations', reservation.toMap()..remove('id'));
  }

  Future<int> update(Reservation reservation) async {
    if (reservation.id == null) throw ArgumentError('Reservation id is required');
    return DbService.instance.update(
      'reservations',
      reservation.toMap(),
      where: 'id = ?',
      whereArgs: [reservation.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('reservations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Reservation>> getAll() async {
    final rows = await DbService.instance.query('''
      SELECT r.*, t.table_number
      FROM reservations r
      LEFT JOIN restaurant_tables t ON t.id = r.table_id
      ORDER BY r.reservation_date DESC
    ''');
    return rows.map(Reservation.fromMap).toList();
  }

  Future<List<Reservation>> getUpcoming() async {
    final now = DateTime.now().toIso8601String();
    final rows = await DbService.instance.query('''
      SELECT r.*, t.table_number
      FROM reservations r
      LEFT JOIN restaurant_tables t ON t.id = r.table_id
      WHERE r.reservation_date >= ? AND r.status != 'Отменено'
      ORDER BY r.reservation_date ASC
    ''', arguments: [now]);
    return rows.map(Reservation.fromMap).toList();
  }

  Future<List<Reservation>> getByDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day).toIso8601String();
    final dayEnd = DateTime(date.year, date.month, date.day + 1).toIso8601String();
    final rows = await DbService.instance.query('''
      SELECT r.*, t.table_number
      FROM reservations r
      LEFT JOIN restaurant_tables t ON t.id = r.table_id
      WHERE r.reservation_date >= ? AND r.reservation_date < ?
      ORDER BY r.reservation_date ASC
    ''', arguments: [dayStart, dayEnd]);
    return rows.map(Reservation.fromMap).toList();
  }

  Future<List<Reservation>> getByTableAndDate(int tableId, DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = await DbService.instance.query('''
      SELECT r.*, t.table_number
      FROM reservations r
      LEFT JOIN restaurant_tables t ON t.id = r.table_id
      WHERE r.table_id = ? AND r.reservation_date >= ? AND r.reservation_date < ?
      ORDER BY r.reservation_date ASC
    ''', arguments: [tableId, dayStart.toIso8601String(), dayEnd.toIso8601String()]);
    return rows.map(Reservation.fromMap).toList();
  }

  Future<void> updateStatus(int id, String status) async {
    await DbService.instance.update(
      'reservations',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> getReservationStats({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final totalRow = await DbService.instance.queryOne(
      '''
      SELECT COUNT(*) as total,
             SUM(CASE WHEN status = 'Подтверждено' THEN 1 ELSE 0 END) as confirmed,
             SUM(CASE WHEN status = 'Выполнено' THEN 1 ELSE 0 END) as completed,
             SUM(CASE WHEN status = 'Отменено' THEN 1 ELSE 0 END) as cancelled,
             SUM(CASE WHEN status = 'Неявка' THEN 1 ELSE 0 END) as no_show
      FROM reservations
      WHERE reservation_date >= ? AND reservation_date < ?
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    return {
      'total': totalRow?['total'] ?? 0,
      'confirmed': totalRow?['confirmed'] ?? 0,
      'completed': totalRow?['completed'] ?? 0,
      'cancelled': totalRow?['cancelled'] ?? 0,
      'no_show': totalRow?['no_show'] ?? 0,
    };
  }
}
