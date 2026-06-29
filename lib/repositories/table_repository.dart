import '../database/db_service.dart';
import '../models/restaurant_table.dart';

class TableRepository {
  const TableRepository();

  Future<int> create(RestaurantTable table) async {
    return DbService.instance.insert('restaurant_tables', table.toMap()..remove('id'));
  }

  Future<int> update(RestaurantTable table) async {
    if (table.id == null) throw ArgumentError('Table id is required');
    return DbService.instance.update(
      'restaurant_tables',
      table.toMap(),
      where: 'id = ?',
      whereArgs: [table.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('restaurant_tables', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RestaurantTable>> getAll() async {
    final rows = await DbService.instance.query(
      'SELECT * FROM restaurant_tables ORDER BY table_number',
    );
    return rows.map(RestaurantTable.fromMap).toList();
  }

  Future<RestaurantTable?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      'SELECT * FROM restaurant_tables WHERE id = ?',
      arguments: [id],
    );
    return row == null ? null : RestaurantTable.fromMap(row);
  }

  Future<void> updateStatus(int id, String status) async {
    await DbService.instance.update(
      'restaurant_tables',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RestaurantTable>> getByZone(String zone) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM restaurant_tables WHERE zone = ? ORDER BY table_number',
      arguments: [zone],
    );
    return rows.map(RestaurantTable.fromMap).toList();
  }

  Future<List<String>> getZones() async {
    final rows = await DbService.instance.query(
      'SELECT DISTINCT zone FROM restaurant_tables ORDER BY zone',
    );
    return rows.map((r) => r['zone'].toString()).toList();
  }

  Future<Map<String, dynamic>> getTablesStats() async {
    final rows = await DbService.instance.query(
      'SELECT status, COUNT(*) as count FROM restaurant_tables GROUP BY status'
    );
    final stats = <String, int>{};
    for (final row in rows) {
      stats[row['status'].toString()] = row['count'] as int;
    }

    final totalRow = await DbService.instance.queryOne(
      'SELECT COUNT(*) as total, SUM(capacity) as total_capacity FROM restaurant_tables'
    );

    return {
      'total': totalRow?['total'] ?? 0,
      'total_capacity': totalRow?['total_capacity'] ?? 0,
      'by_status': stats,
    };
  }

  Future<RestaurantTable?> getAvailableTable(int partySize, {String? zone}) async {
    String where = "status = 'Свободен' AND capacity >= ?";
    List<dynamic> args = [partySize];
    if (zone != null) {
      where += ' AND zone = ?';
      args.add(zone);
    }
    where += ' ORDER BY capacity ASC LIMIT 1';

    final row = await DbService.instance.queryOne(
      'SELECT * FROM restaurant_tables WHERE $where',
      arguments: args,
    );
    return row == null ? null : RestaurantTable.fromMap(row);
  }
}
