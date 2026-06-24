import '../database/db_service.dart';
import '../models/category.dart';

class CategoryRepository {
  const CategoryRepository();

  Future<int> create(Category category) async {
    final rows = await DbService.instance.query(
      '''
      INSERT INTO categories (name, description)
      VALUES (@name, @description)
      RETURNING id
      ''',
      parameters: {
        'name': category.name.trim(),
        'description': category.description?.trim(),
      },
    );
    return (rows.first['id'] as num).toInt();
  }

  Future<List<Category>> getAll() async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, name, description, created_at
      FROM categories
      ORDER BY name
      ''',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<Category?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      '''
      SELECT id, name, description, created_at
      FROM categories
      WHERE id = @id
      ''',
      parameters: {'id': id},
    );
    return row == null ? null : Category.fromMap(row);
  }

  Future<int> update(Category category) async {
    if (category.id == null) {
      throw ArgumentError('Category id is required for update');
    }

    final rows = await DbService.instance.query(
      '''
      UPDATE categories
      SET name = @name,
          description = @description
      WHERE id = @id
      RETURNING id
      ''',
      parameters: {
        'id': category.id,
        'name': category.name.trim(),
        'description': category.description?.trim(),
      },
    );
    return rows.length;
  }

  Future<int> delete(int id) async {
    final rows = await DbService.instance.query(
      'DELETE FROM categories WHERE id = @id RETURNING id',
      parameters: {'id': id},
    );
    return rows.length;
  }

  Future<List<Category>> search(String keyword) async {
    final rows = await DbService.instance.query(
      '''
      SELECT id, name, description, created_at
      FROM categories
      WHERE name ILIKE @keyword
         OR COALESCE(description, '') ILIKE @keyword
      ORDER BY name
      ''',
      parameters: {'keyword': '%${keyword.trim()}%'},
    );
    return rows.map(Category.fromMap).toList();
  }
}
