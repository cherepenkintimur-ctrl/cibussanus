import '../database/db_service.dart';
import '../models/dish.dart';

class DishRepository {
  const DishRepository();

  Future<int> create(Dish dish) async {
    final id = await DbService.instance.insert('dishes', {
      'category_id': dish.categoryId,
      'name': dish.name.trim(),
      'price': dish.price,
      'description': dish.description?.trim(),
      'volume': dish.volume,
      'unit': dish.unit,
      'is_active': dish.isActive ? 1 : 0,
    });
    return id;
  }

  Future<List<Dish>> getAll({bool onlyActive = false}) async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, category_id, name, price, description, volume, unit, cost_price, is_active, created_at
      FROM dishes
      ${onlyActive ? 'WHERE is_active = 1' : ''}
      ORDER BY name
      ''',
    );
    return rows.map(Dish.fromMap).toList();
  }

  Future<List<Dish>> getByCategory(int categoryId) async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, category_id, name, price, description, volume, unit, cost_price, is_active, created_at
      FROM dishes
      WHERE category_id = ?
      ORDER BY name
      ''',
      arguments: [categoryId],
    );
    return rows.map(Dish.fromMap).toList();
  }

  Future<Dish?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      '''
      SELECT id, category_id, name, price, description, volume, unit, cost_price, is_active, created_at
      FROM dishes WHERE id = ?
      ''',
      arguments: [id],
    );
    return row == null ? null : Dish.fromMap(row);
  }

  Future<int> update(Dish dish) async {
    if (dish.id == null) {
      throw ArgumentError('Dish id is required for update');
    }
    return DbService.instance.update(
      'dishes',
      {
        'category_id': dish.categoryId,
        'name': dish.name.trim(),
        'price': dish.price,
        'description': dish.description?.trim(),
        'volume': dish.volume,
        'unit': dish.unit,
        'is_active': dish.isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [dish.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete(
      'dishes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> toggleActive(int id, bool active) async {
    return DbService.instance.update(
      'dishes',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Dish>> search(String keyword) async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, category_id, name, price, description, volume, unit, cost_price, is_active, created_at
      FROM dishes
      WHERE name LIKE ? OR COALESCE(description, '') LIKE ?
      ORDER BY name
      ''',
      arguments: ['%${keyword.trim()}%', '%${keyword.trim()}%'],
    );
    return rows.map(Dish.fromMap).toList();
  }
}
