import '../database/db_service.dart';
import '../models/expense.dart';

class ExpenseRepository {
  const ExpenseRepository();

  Future<int> create(Expense expense) async {
    return DbService.instance.insert('expenses', expense.toMap()..remove('id'));
  }

  Future<int> update(Expense expense) async {
    if (expense.id == null) throw ArgumentError('Expense id is required');
    return DbService.instance.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> delete(int id) async {
    return DbService.instance.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> getAll() async {
    final rows = await DbService.instance.query(
      'SELECT * FROM expenses ORDER BY expense_date DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> search(String keyword) async {
    final q = keyword.trim();
    final rows = await DbService.instance.query(
      'SELECT * FROM expenses WHERE category LIKE ? OR description LIKE ? OR COALESCE(supplier, '') LIKE ? OR COALESCE(receipt_number, '') LIKE ? ORDER BY expense_date DESC',
      arguments: ['%$q%', '%$q%', '%$q%', '%$q%'],
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getByCategory(String category) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM expenses WHERE category = ? ORDER BY expense_date DESC',
      arguments: [category],
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getByPeriod(DateTime start, DateTime end) async {
    final rows = await DbService.instance.query(
      'SELECT * FROM expenses WHERE expense_date >= ? AND expense_date < ? ORDER BY expense_date DESC',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<String>> getCategories() async {
    final rows = await DbService.instance.query(
      'SELECT DISTINCT category FROM expenses ORDER BY category',
    );
    return rows.map((r) => r['category'].toString()).toList();
  }

  Future<Map<String, dynamic>> getExpensesSummary({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final totalRow = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(SUM(amount), 0) as total_expenses
      FROM expenses WHERE expense_date >= ? AND expense_date < ?
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final byCategory = await DbService.instance.query(
      '''
      SELECT category, COALESCE(SUM(amount), 0) as total, COUNT(*) as count
      FROM expenses WHERE expense_date >= ? AND expense_date < ?
      GROUP BY category ORDER BY total DESC
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final monthlyTrend = await DbService.instance.query(
      '''
      SELECT
        strftime('%Y-%m', expense_date) as month,
        COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      GROUP BY strftime('%Y-%m', expense_date)
      ORDER BY month
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    return {
      'total_expenses': totalRow?['total_expenses'] ?? 0.0,
      'by_category': byCategory,
      'monthly_trend': monthlyTrend,
    };
  }

  Future<List<Map<String, dynamic>>> getCategoryBreakdown({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    return DbService.instance.query(
      '''
      SELECT
        category,
        COALESCE(SUM(amount), 0) as total,
        COUNT(*) as count,
        COALESCE(AVG(amount), 0) as avg_expense
      FROM expenses WHERE expense_date >= ? AND expense_date < ?
      GROUP BY category ORDER BY total DESC
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );
  }
}
