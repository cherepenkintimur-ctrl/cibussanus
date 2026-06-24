import '../database/db_service.dart';
import '../models/converters.dart';

class ReportRepository {
  const ReportRepository();

  Future<double> revenueByPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final row = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(SUM(total_amount), 0) AS revenue
      FROM orders
      WHERE order_date >= @start_date
        AND order_date < @end_date
      ''',
      parameters: {
        'start_date': startDate,
        'end_date': endDate,
      },
    );

    return row == null ? 0.0 : parseDouble(row['revenue']);
  }

  Future<Map<String, double>> checkStatisticsByPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final row = await DbService.instance.queryOne(
      '''
      SELECT
          COALESCE(AVG(total_amount), 0) AS average_check,
          COALESCE(MAX(total_amount), 0) AS maximum_check,
          COALESCE(MIN(total_amount), 0) AS minimum_check
      FROM orders
      WHERE order_date >= @start_date
        AND order_date < @end_date
      ''',
      parameters: {
        'start_date': startDate,
        'end_date': endDate,
      },
    );

    return {
      'average_check': row == null ? 0.0 : parseDouble(row['average_check']),
      'maximum_check': row == null ? 0.0 : parseDouble(row['maximum_check']),
      'minimum_check': row == null ? 0.0 : parseDouble(row['minimum_check']),
    };
  }

  Future<List<Map<String, dynamic>>> hourlyLoadByPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return DbService.instance.query(
      '''
      SELECT
          EXTRACT(HOUR FROM order_date)::int AS hour,
          COUNT(*) AS orders_count,
          COALESCE(SUM(total_amount), 0) AS revenue
      FROM orders
      WHERE order_date >= @start_date
        AND order_date < @end_date
      GROUP BY 1
      ORDER BY 1
      ''',
      parameters: {
        'start_date': startDate,
        'end_date': endDate,
      },
    );
  }

  Future<List<Map<String, dynamic>>> topDishesByPeriod({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    return DbService.instance.query(
      '''
      SELECT
          d.id AS dish_id,
          d.name AS dish_name,
          SUM(oi.quantity) AS quantity_sold,
          COALESCE(SUM(oi.line_total), 0) AS revenue
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN dishes d ON d.id = oi.dish_id
      WHERE o.order_date >= @start_date
        AND o.order_date < @end_date
      GROUP BY d.id, d.name
      ORDER BY quantity_sold DESC, revenue DESC
      LIMIT @limit
      ''',
      parameters: {
        'start_date': startDate,
        'end_date': endDate,
        'limit': limit,
      },
    );
  }
}
