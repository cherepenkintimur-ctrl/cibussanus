import '../database/db_service.dart';
import '../models/inventory_item.dart';

class InventoryRepository {
  const InventoryRepository();

  Future<int> create(InventoryItem item) async {
    return DbService.instance.insert('inventory', item.toMap()..remove('id'));
  }

  Future<int> update(InventoryItem item) async {
    if (item.id == null) throw ArgumentError('InventoryItem id is required');
    return DbService.instance.update(
      'inventory',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('inventory', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<InventoryItem>> getAll() async {
    final rows = await DbService.instance.query(
      'SELECT * FROM inventory ORDER BY category, name',
    );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<List<InventoryItem>> getLowStock() async {
    final rows = await DbService.instance.query(
      'SELECT * FROM inventory WHERE current_stock <= min_stock ORDER BY category, name',
    );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<List<String>> getCategories() async {
    final rows = await DbService.instance.query(
      'SELECT DISTINCT category FROM inventory ORDER BY category',
    );
    return rows.map((r) => r['category'].toString()).toList();
  }

  Future<void> restock(int id, double quantity) async {
    await DbService.instance.execute(
      '''
      UPDATE inventory SET
        current_stock = MIN(current_stock + ?, max_stock),
        last_restocked = datetime('now')
      WHERE id = ?
      ''',
      arguments: [quantity, id],
    );
  }

  Future<void> deductStock(int id, double quantity) async {
    await DbService.instance.execute(
      'UPDATE inventory SET current_stock = MAX(current_stock - ?, 0) WHERE id = ?',
      arguments: [quantity, id],
    );
  }

  Future<Map<String, dynamic>> getInventoryStats() async {
    final totalRow = await DbService.instance.queryOne(
      'SELECT COUNT(*) as total, COALESCE(SUM(current_stock * cost_per_unit), 0) as total_value FROM inventory'
    );
    final lowStockCount = await DbService.instance.queryOne(
      'SELECT COUNT(*) as cnt FROM inventory WHERE current_stock <= min_stock'
    );
    final byCategory = await DbService.instance.query(
      '''
      SELECT category, COUNT(*) as count, COALESCE(SUM(current_stock * cost_per_unit), 0) as value
      FROM inventory GROUP BY category ORDER BY value DESC
      '''
    );
    return {
      'total_items': totalRow?['total'] ?? 0,
      'total_value': totalRow?['total_value'] ?? 0.0,
      'low_stock_count': lowStockCount?['cnt'] ?? 0,
      'by_category': byCategory,
    };
  }
}
