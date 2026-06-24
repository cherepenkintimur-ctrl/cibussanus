import '../database/db_service.dart';
import '../models/dish.dart';

class DishRepository {
  const DishRepository();

  Future<int> create(Dish dish) async {
    final rows = await DbService.instance.query(
      '''
      INSERT INTO dishes (category_id, name, price, description, is_active)
      VALUES (@category_id, @name, @price, @description, @is_active)
      RETURNING id
      ''',
      parameters: {
        'category_id': dish.categoryId,
        'name': dish.name.trim(),
        'price': dish.price,
        'description': dish.description?.trim(),
        'is_active': dish.isActive,
      },
    );
    return (rows.first['id'] as num).toInt();
  }

  Future<List<Dish>> getAll({bool onlyActive = false}) async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, category_id, name, price, description, is_active, created_at
      FROM dishes
      ${onlyActive ? 'WHERE is_active = TRUE' : ''}
      ORDER BY name
      ''',
    );
    return rows.map(Dish.fromMap).toList();
  }

  Future<List<Dish>> getByCategory(int categoryId) async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, category_id, name, price, description, is_active, created_at
      FROM dishes
      WHERE category_id = @category_id
      ORDER BY name
      ''',
      parameters: {'category_id': categoryId},
    );
    return rows.map(Dish.fromMap).toList();
  }

  Future<Dish?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      '''
      SELECT id, category_id, name, price, description, is_active, created_at
      FROM dishes
      WHERE id = @id
      ''',
      parameters: {'id': id},
    );
    return row == null ? null : Dish.fromMap(row);
  }

  Future<int> update(Dish dish) async {
    if (dish.id == null) {
      throw ArgumentError('Dish id is required for update');
    }

    final rows = await DbService.instance.query(
      '''
      UPDATE dishes
      SET category_id = @category_id,
          name = @name,
          price = @price,
          description = @description,
          is_active = @is_active
      WHERE id = @id
      RETURNING id
      ''',
      parameters: {
        'id': dish.id,
        'category_id': dish.categoryId,
        'name': dish.name.trim(),
        'price': dish.price,
        'description': dish.description?.trim(),
        'is_active': dish.isActive,
      },
    );
    return rows.length;
  }

  Future<int> delete(int id) async {
    final rows = await DbService.instance.query(
      'DELETE FROM dishes WHERE id = @id RETURNING id',
      parameters: {'id': id},
    );
    return rows.length;
  }

  Future<int> toggleActive(int id, bool active) async {
    final rows = await DbService.instance.query(
      '''
      UPDATE dishes
      SET is_active = @active
      WHERE id = @id
      RETURNING id
      ''',
      parameters: {'id': id, 'active': active},
    );
    return rows.length;
  }

  Future<List<Dish>> search(String keyword) async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, category_id, name, price, description, is_active, created_at
      FROM dishes
      WHERE name ILIKE @keyword
         OR COALESCE(description, '') ILIKE @keyword
      ORDER BY name
      ''',
      parameters: {'keyword': '%${keyword.trim()}%'},
    );
    return rows.map(Dish.fromMap).toList();
  }
}
