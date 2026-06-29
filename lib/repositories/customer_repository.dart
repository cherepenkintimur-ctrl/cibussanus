import '../database/db_service.dart';
import '../models/customer.dart';

class CustomerRepository {
  const CustomerRepository();

  Future<int> create(Customer customer) async {
    return DbService.instance.insert('customers', customer.toMap()..remove('id'));
  }

  Future<int> update(Customer customer) async {
    if (customer.id == null) throw ArgumentError('Customer id is required');
    return DbService.instance.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Customer>> getAll() async {
    final rows = await DbService.instance.query(
      'SELECT * FROM customers ORDER BY total_spent DESC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getById(int id) async {
    final row = await DbService.instance.queryOne(
      'SELECT * FROM customers WHERE id = ?',
      arguments: [id],
    );
    return row == null ? null : Customer.fromMap(row);
  }

  Future<List<Customer>> search(String query) async {
    final rows = await DbService.instance.query(
      "SELECT * FROM customers WHERE name LIKE ? OR phone LIKE ? OR email LIKE ? ORDER BY name",
      arguments: ['%$query%', '%$query%', '%$query%'],
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<void> incrementVisit(int customerId, double amount) async {
    await DbService.instance.execute(
      '''
      UPDATE customers SET
        visit_count = visit_count + 1,
        total_spent = total_spent + ?,
        last_visit = datetime('now')
      WHERE id = ?
      ''',
      arguments: [amount, customerId],
    );
  }

  Future<List<Customer>> getTopCustomers({int limit = 10}) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM customers ORDER BY total_spent DESC LIMIT ?',
      arguments: [limit],
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Map<String, dynamic>> getCustomerStats() async {
    final totalRow = await DbService.instance.queryOne(
      'SELECT COUNT(*) as total, COALESCE(SUM(total_spent), 0) as total_revenue, COALESCE(AVG(total_spent), 0) as avg_spent FROM customers'
    );
    final tierRows = await DbService.instance.query(
      '''
      SELECT
        CASE
          WHEN total_spent >= 100000 OR visit_count >= 50 THEN 'Платиновый'
          WHEN total_spent >= 50000 OR visit_count >= 25 THEN 'Золотой'
          WHEN total_spent >= 20000 OR visit_count >= 10 THEN 'Серебряный'
          WHEN visit_count >= 3 THEN 'Бронзовый'
          ELSE 'Гость'
        END as tier,
        COUNT(*) as count
      FROM customers GROUP BY tier ORDER BY total_spent DESC
      ''',
    );
    return {
      'total_customers': totalRow?['total'] ?? 0,
      'total_revenue': totalRow?['total_revenue'] ?? 0.0,
      'avg_spent': totalRow?['avg_spent'] ?? 0.0,
      'by_tier': tierRows,
    };
  }
}
