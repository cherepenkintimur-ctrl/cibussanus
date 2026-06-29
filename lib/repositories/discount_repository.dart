import '../database/db_service.dart';
import '../models/discount.dart';

class DiscountRepository {
  const DiscountRepository();

  Future<int> create(Discount discount) async {
    return DbService.instance.insert('discounts', discount.toMap()..remove('id'));
  }

  Future<int> update(Discount discount) async {
    if (discount.id == null) throw ArgumentError('Discount id is required');
    return DbService.instance.update(
      'discounts',
      discount.toMap(),
      where: 'id = ?',
      whereArgs: [discount.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('discounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Discount>> getAll() async {
    final rows = await DbService.instance.query(
      'SELECT * FROM discounts ORDER BY code',
    );
    return rows.map(Discount.fromMap).toList();
  }

  Future<Discount?> getByCode(String code) async {
    final row = await DbService.instance.queryOne(
      "SELECT * FROM discounts WHERE code = ? AND is_active = 1",
      arguments: [code],
    );
    return row == null ? null : Discount.fromMap(row);
  }

  Future<void> incrementUsage(int id) async {
    await DbService.instance.execute(
      'UPDATE discounts SET usage_count = usage_count + 1 WHERE id = ?',
      arguments: [id],
    );
  }

  Future<void> toggleActive(int id) async {
    await DbService.instance.execute(
      'UPDATE discounts SET is_active = CASE WHEN is_active = 1 THEN 0 ELSE 1 END WHERE id = ?',
      arguments: [id],
    );
  }

  Future<List<Discount>> getActive() async {
    final now = DateTime.now().toIso8601String();
    final rows = await DbService.instance.query(
      '''
      SELECT * FROM discounts
      WHERE is_active = 1 AND valid_from <= ? AND valid_to >= ?
      AND (usage_limit IS NULL OR usage_count < usage_limit)
      ORDER BY code
      ''',
      arguments: [now, now],
    );
    return rows.map(Discount.fromMap).toList();
  }

  Future<Map<String, dynamic>> getDiscountStats({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final totalDiscountGiven = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(SUM(discount_amount), 0) as total_discount
      FROM orders WHERE discount_id IS NOT NULL AND order_date >= ? AND order_date < ?
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final byDiscount = await DbService.instance.query(
      '''
      SELECT
        d.code,
        d.description,
        d.type,
        d.value,
        COUNT(o.id) as usage_count,
        COALESCE(SUM(o.discount_amount), 0) as total_discount_amount
      FROM discounts d
      LEFT JOIN orders o ON o.discount_id = d.id AND o.order_date >= ? AND o.order_date < ?
      GROUP BY d.id, d.code, d.description, d.type, d.value
      ORDER BY total_discount_amount DESC
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    return {
      'total_discount_given': totalDiscountGiven?['total_discount'] ?? 0.0,
      'by_discount': byDiscount,
    };
  }
}
