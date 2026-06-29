import '../database/db_service.dart';

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
      WHERE order_date >= ? AND order_date < ?
      ''',
      arguments: [startDate.toIso8601String(), endDate.toIso8601String()],
    );
    return row == null ? 0.0 : (row['revenue'] as num).toDouble();
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
      WHERE order_date >= ? AND order_date < ?
      ''',
      arguments: [startDate.toIso8601String(), endDate.toIso8601String()],
    );
    return {
      'average_check': row == null ? 0.0 : (row['average_check'] as num).toDouble(),
      'maximum_check': row == null ? 0.0 : (row['maximum_check'] as num).toDouble(),
      'minimum_check': row == null ? 0.0 : (row['minimum_check'] as num).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> hourlyLoadByPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return DbService.instance.query(
      '''
      SELECT
          CAST(strftime('%H', order_date) AS INTEGER) AS hour,
          COUNT(*) AS orders_count,
          COALESCE(SUM(total_amount), 0) AS revenue
      FROM orders
      WHERE order_date >= ? AND order_date < ?
      GROUP BY strftime('%H', order_date)
      ORDER BY hour
      ''',
      arguments: [startDate.toIso8601String(), endDate.toIso8601String()],
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
          d.cost_price,
          SUM(oi.quantity) AS quantity_sold,
          COALESCE(SUM(oi.line_total), 0) AS revenue,
          COALESCE(SUM(oi.quantity * d.cost_price), 0) AS total_cost,
          COALESCE(SUM(oi.line_total) - SUM(oi.quantity * d.cost_price), 0) AS profit,
          CASE WHEN SUM(oi.line_total) > 0
            THEN ((SUM(oi.line_total) - SUM(oi.quantity * d.cost_price)) / SUM(oi.line_total)) * 100
            ELSE 0
          END AS margin_percent
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN dishes d ON d.id = oi.dish_id
      WHERE o.order_date >= ? AND o.order_date < ?
      GROUP BY d.id, d.name, d.cost_price
      ORDER BY quantity_sold DESC, revenue DESC
      LIMIT ?
      ''',
      arguments: [startDate.toIso8601String(), endDate.toIso8601String(), limit],
    );
  }

  // Menu Engineering analysis
  Future<Map<String, dynamic>> menuEngineering({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 90));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final avgPopularity = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(AVG(qty), 0) as avg_qty, COALESCE(AVG(rev), 0) as avg_rev
      FROM (
        SELECT d.id, SUM(oi.quantity) as qty, SUM(oi.line_total) as rev
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        JOIN dishes d ON d.id = oi.dish_id
        WHERE o.order_date >= ? AND o.order_date < ?
        GROUP BY d.id
      )
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final avgQty = (avgPopularity?['avg_qty'] as num?)?.toDouble() ?? 0;
    final avgRev = (avgPopularity?['avg_rev'] as num?)?.toDouble() ?? 0;

    final dishes = await DbService.instance.query(
      '''
      SELECT
        d.id, d.name, d.price, d.cost_price,
        SUM(oi.quantity) as quantity_sold,
        SUM(oi.line_total) as revenue,
        SUM(oi.quantity * d.cost_price) as total_cost,
        CASE WHEN SUM(oi.line_total) > 0
          THEN (SUM(oi.line_total) - SUM(oi.quantity * d.cost_price)) / SUM(oi.line_total) * 100
          ELSE 0
        END as margin_percent
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN dishes d ON d.id = oi.dish_id
      WHERE o.order_date >= ? AND o.order_date < ?
      GROUP BY d.id, d.name, d.price, d.cost_price
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final classified = dishes.map((d) {
      final qty = (d['quantity_sold'] as num?)?.toDouble() ?? 0;
      final rev = (d['revenue'] as num?)?.toDouble() ?? 0;

      String category;
      if (rev >= avgRev && qty >= avgQty) {
        category = 'star';
      } else if (rev >= avgRev && qty < avgQty) {
        category = 'puzzle';
      } else if (rev < avgRev && qty >= avgQty) {
        category = 'workhorse';
      } else {
        category = 'dog';
      }

      return {
        ...d.map((k, v) => MapEntry(k.toString(), v)),
        'menu_category': category,
      };
    }).toList();

    return {
      'dishes': classified,
      'stars': classified.where((d) => d['menu_category'] == 'star').toList(),
      'puzzles': classified.where((d) => d['menu_category'] == 'puzzle').toList(),
      'workhorses': classified.where((d) => d['menu_category'] == 'workhorse').toList(),
      'dogs': classified.where((d) => d['menu_category'] == 'dog').toList(),
    };
  }

  // Revenue forecast based on trend
  Future<Map<String, dynamic>> revenueForecast({int forecastDays = 30}) async {
    final now = DateTime.now();
    final last90 = now.subtract(const Duration(days: 90));

    final dailyRevenue = await DbService.instance.query(
      '''
      SELECT DATE(order_date) as date, SUM(total_amount) as revenue
      FROM orders
      WHERE order_date >= ? AND order_date < ?
      GROUP BY DATE(order_date)
      ORDER BY date
      ''',
      arguments: [last90.toIso8601String(), now.toIso8601String()],
    );

    if (dailyRevenue.isEmpty) {
      return {'daily_data': [], 'forecast': [], 'avg_daily': 0, 'trend': 0};
    }

    double totalRev = 0;
    for (final row in dailyRevenue) {
      totalRev += (row['revenue'] as num?)?.toDouble() ?? 0;
    }
    final avgDaily = totalRev / dailyRevenue.length;

    final recent7 = dailyRevenue.length >= 7
        ? dailyRevenue.sublist(dailyRevenue.length - 7)
        : dailyRevenue;
    double recentTotal = 0;
    for (final row in recent7) {
      recentTotal += (row['revenue'] as num?)?.toDouble() ?? 0;
    }
    final recentAvg = recentTotal / recent7.length;

    final trend = avgDaily > 0 ? ((recentAvg - avgDaily) / avgDaily) * 100 : 0;

    final forecast = <Map<String, dynamic>>[];
    for (int i = 1; i <= forecastDays; i++) {
      final forecastDate = now.add(Duration(days: i));
      final predictedRevenue = recentAvg * (1 + (trend / 100 * i / forecastDays));
      forecast.add({
        'date': forecastDate.toIso8601String().substring(0, 10),
        'predicted_revenue': predictedRevenue,
      });
    }

    return {
      'daily_data': dailyRevenue,
      'forecast': forecast,
      'avg_daily': avgDaily,
      'recent_avg': recentAvg,
      'trend': trend,
    };
  }

  // Day-to-day comparison
  Future<Map<String, dynamic>> dayComparison(DateTime date1, DateTime date2) async {
    Future<Map<String, dynamic>> getDayStats(DateTime date) async {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final row = await DbService.instance.queryOne(
        '''
        SELECT
          COUNT(*) as order_count,
          COALESCE(SUM(total_amount), 0) as revenue,
          COALESCE(AVG(total_amount), 0) as avg_check
        FROM orders WHERE order_date >= ? AND order_date < ?
        ''',
        arguments: [start.toIso8601String(), end.toIso8601String()],
      );
      return {
        'order_count': row?['order_count'] ?? 0,
        'revenue': row?['revenue'] ?? 0.0,
        'avg_check': row?['avg_check'] ?? 0.0,
      };
    }

    final stats1 = await getDayStats(date1);
    final stats2 = await getDayStats(date2);

    return {
      'day1': stats1,
      'day2': stats2,
    };
  }

  // Week-to-week comparison
  Future<Map<String, dynamic>> weekComparison(DateTime week1Start, DateTime week2Start) async {
    Future<Map<String, dynamic>> getWeekStats(DateTime start) async {
      final end = start.add(const Duration(days: 7));
      final row = await DbService.instance.queryOne(
        '''
        SELECT
          COUNT(*) as order_count,
          COALESCE(SUM(total_amount), 0) as revenue,
          COALESCE(AVG(total_amount), 0) as avg_check,
          COALESCE(AVG(total_amount / 7), 0) as daily_avg
        FROM orders WHERE order_date >= ? AND order_date < ?
        ''',
        arguments: [start.toIso8601String(), end.toIso8601String()],
      );
      return {
        'order_count': row?['order_count'] ?? 0,
        'revenue': row?['revenue'] ?? 0.0,
        'avg_check': row?['avg_check'] ?? 0.0,
        'daily_avg': row?['daily_avg'] ?? 0.0,
      };
    }

    final stats1 = await getWeekStats(week1Start);
    final stats2 = await getWeekStats(week2Start);

    return {'week1': stats1, 'week2': stats2};
  }

  // Month-to-month comparison
  Future<Map<String, dynamic>> monthComparison(int year1, int month1, int year2, int month2) async {
    Future<Map<String, dynamic>> getMonthStats(int year, int month) async {
      final start = DateTime(year, month, 1);
      final end = (month < 12) ? DateTime(year, month + 1, 1) : DateTime(year + 1, 1, 1);
      final row = await DbService.instance.queryOne(
        '''
        SELECT
          COUNT(*) as order_count,
          COALESCE(SUM(total_amount), 0) as revenue,
          COALESCE(AVG(total_amount), 0) as avg_check
        FROM orders WHERE order_date >= ? AND order_date < ?
        ''',
        arguments: [start.toIso8601String(), end.toIso8601String()],
      );
      return {
        'order_count': row?['order_count'] ?? 0,
        'revenue': row?['revenue'] ?? 0.0,
        'avg_check': row?['avg_check'] ?? 0.0,
      };
    }

    final stats1 = await getMonthStats(year1, month1);
    final stats2 = await getMonthStats(year2, month2);

    return {'month1': stats1, 'month2': stats2};
  }

  // Waiter performance
  Future<List<Map<String, dynamic>>> waiterPerformance({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    return DbService.instance.query(
      '''
      SELECT
        w.id,
        w.name,
        w.role,
        COUNT(o.id) as order_count,
        COALESCE(SUM(o.total_amount), 0) as total_revenue,
        COALESCE(AVG(o.total_amount), 0) as avg_check,
        COALESCE(AVG(
          SELECT SUM(oi.quantity) FROM order_items oi WHERE oi.order_id = o.id
        ), 0) as avg_items_per_order,
        (SELECT COALESCE(SUM(t.amount), 0) FROM tips t WHERE t.waiter_id = w.id AND t.created_at >= ? AND t.created_at < ?) as total_tips,
        (SELECT COUNT(*) FROM shifts s WHERE s.waiter_id = w.id AND s.start_time >= ? AND s.start_time < ?) as shift_count
      FROM waiters w
      LEFT JOIN orders o ON o.waiter_id = w.id AND o.order_date >= ? AND o.order_date < ?
      WHERE w.is_active = 1
      GROUP BY w.id, w.name, w.role
      ORDER BY total_revenue DESC
      ''',
      arguments: [
        start.toIso8601String(), end.toIso8601String(),
        start.toIso8601String(), end.toIso8601String(),
        start.toIso8601String(), end.toIso8601String(),
      ],
    );
  }

  // Daily revenue trend
  Future<List<Map<String, dynamic>>> dailyRevenueTrend({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    return DbService.instance.query(
      '''
      SELECT
        DATE(order_date) as date,
        COUNT(*) as order_count,
        COALESCE(SUM(total_amount), 0) as revenue
      FROM orders
      WHERE order_date >= ? AND order_date < ?
      GROUP BY DATE(order_date)
      ORDER BY date
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );
  }

  // Payment method breakdown
  Future<Map<String, dynamic>> paymentMethodBreakdown({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final rows = await DbService.instance.query(
      '''
      SELECT
        COALESCE(payment_method, 'Не указан') as method,
        COUNT(*) as count,
        COALESCE(SUM(total_amount), 0) as total,
        COALESCE(AVG(total_amount), 0) as avg
      FROM orders
      WHERE order_date >= ? AND order_date < ?
      GROUP BY payment_method
      ORDER BY total DESC
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );
    return {'methods': rows};
  }

  // Cost analysis
  Future<Map<String, dynamic>> costAnalysis({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final revenue = await revenueByPeriod(startDate: start, endDate: end);

    final costRow = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(SUM(oi.quantity * d.cost_price), 0) as food_cost
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN dishes d ON d.id = oi.dish_id
      WHERE o.order_date >= ? AND o.order_date < ?
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final expenseRow = await DbService.instance.queryOne(
      '''
      SELECT COALESCE(SUM(amount), 0) as operating_expenses
      FROM expenses WHERE expense_date >= ? AND expense_date < ?
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final foodCost = (costRow?['food_cost'] as num?)?.toDouble() ?? 0;
    final operatingExpenses = (expenseRow?['operating_expenses'] as num?)?.toDouble() ?? 0;
    final totalCosts = foodCost + operatingExpenses;
    final netProfit = revenue - totalCosts;

    return {
      'revenue': revenue,
      'food_cost': foodCost,
      'operating_expenses': operatingExpenses,
      'total_costs': totalCosts,
      'net_profit': netProfit,
      'food_cost_percent': revenue > 0 ? (foodCost / revenue * 100) : 0,
      'profit_margin': revenue > 0 ? (netProfit / revenue * 100) : 0,
    };
  }

  // Table utilization
  Future<Map<String, dynamic>> tableUtilization({DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    final rows = await DbService.instance.query(
      '''
      SELECT
        t.id,
        t.table_number,
        t.capacity,
        t.zone,
        COUNT(o.id) as order_count,
        COALESCE(SUM(o.total_amount), 0) as total_revenue,
        COALESCE(AVG(o.total_amount), 0) as avg_check
      FROM restaurant_tables t
      LEFT JOIN orders o ON o.table_id = t.id AND o.order_date >= ? AND o.order_date < ?
      GROUP BY t.id, t.table_number, t.capacity, t.zone
      ORDER BY total_revenue DESC
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final totalTables = rows.length;
    final usedTables = rows.where((r) => (r['order_count'] as int? ?? 0) > 0).length;
    final utilizationRate = totalTables > 0 ? (usedTables / totalTables * 100) : 0.0;
    final mostProfitable = rows.take(3).toList();
    final zones = rows.fold<Map<String, double>>({}, (acc, r) {
      final zone = r['zone']?.toString() ?? '—';
      acc[zone] = (acc[zone] ?? 0) + (r['total_revenue'] as num? ?? 0).toDouble();
      return acc;
    });
    final zoneBreakdown = zones.entries.map((e) => {'zone': e.key, 'revenue': e.value}).toList();

    return {
      'utilizationRate': utilizationRate,
      'totalTables': totalTables,
      'mostProfitable': mostProfitable,
      'zones': zoneBreakdown,
    };
  }

  Future<Map<String, dynamic>> profitAndLoss(DateTime startDate, DateTime endDate) async {
    // Revenue
    final revRow = await DbService.instance.queryOne('''
      SELECT COALESCE(SUM(total_amount), 0) as revenue,
             COUNT(*) as order_count,
             COALESCE(AVG(total_amount), 0) as avg_check
      FROM orders WHERE order_date >= ? AND order_date < ?
    ''', arguments: [startDate.toIso8601String(), endDate.toIso8601String()]);

    // Cost of goods sold (from order_items * dish cost_price)
    final cogsRow = await DbService.instance.queryOne('''
      SELECT COALESCE(SUM(d.cost_price * oi.quantity), 0) as cogs
      FROM order_items oi
      JOIN dishes d ON d.id = oi.dish_id
      JOIN orders o ON o.id = oi.order_id
      WHERE o.order_date >= ? AND o.order_date < ?
    ''', arguments: [startDate.toIso8601String(), endDate.toIso8601String()]);

    // Labor costs (salaries from expenses table)
    final laborRow = await DbService.instance.queryOne('''
      SELECT COALESCE(SUM(amount), 0) as labor
      FROM expenses WHERE category = 'Зарплата' AND expense_date >= ? AND expense_date < ?
    ''', arguments: [startDate.toIso8601String(), endDate.toIso8601String()]);

    // Operating expenses (all expenses except salary)
    final opexRow = await DbService.instance.queryOne('''
      SELECT COALESCE(SUM(amount), 0) as opex
      FROM expenses WHERE category != 'Зарплата' AND expense_date >= ? AND expense_date < ?
    ''', arguments: [startDate.toIso8601String(), endDate.toIso8601String()]);

    final revenue = (revRow?['revenue'] as num?)?.toDouble() ?? 0;
    final cogs = (cogsRow?['cogs'] as num?)?.toDouble() ?? 0;
    final labor = (laborRow?['labor'] as num?)?.toDouble() ?? 0;
    final opex = (opexRow?['opex'] as num?)?.toDouble() ?? 0;
    final grossProfit = revenue - cogs;
    final netProfit = revenue - cogs - labor - opex;
    final grossMargin = revenue > 0 ? (grossProfit / revenue * 100) : 0;
    final netMargin = revenue > 0 ? (netProfit / revenue * 100) : 0;

    return {
      'revenue': revenue,
      'order_count': (revRow?['order_count'] as num?)?.toInt() ?? 0,
      'avg_check': (revRow?['avg_check'] as num?)?.toDouble() ?? 0,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'gross_margin': grossMargin,
      'labor': labor,
      'opex': opex,
      'total_expenses': cogs + labor + opex,
      'net_profit': netProfit,
      'net_margin': netMargin,
    };
  }

  // Today's dashboard stats
  Future<Map<String, dynamic>> todayStats() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final todayRow = await DbService.instance.queryOne(
      '''
      SELECT
        COUNT(*) as order_count,
        COALESCE(SUM(total_amount), 0) as revenue,
        COALESCE(AVG(total_amount), 0) as avg_check,
        COALESCE(MAX(total_amount), 0) as max_check
      FROM orders WHERE order_date >= ? AND order_date < ?
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final activeOrders = await DbService.instance.queryOne(
      "SELECT COUNT(*) as cnt FROM orders WHERE status IN ('Новый', 'Готовится', 'Подан') AND order_date >= ? AND order_date < ?",
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final tipsToday = await DbService.instance.queryOne(
      "SELECT COALESCE(SUM(amount), 0) as total FROM tips WHERE created_at >= ? AND created_at < ?",
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final tablesFree = await DbService.instance.queryOne(
      "SELECT COUNT(*) as cnt FROM restaurant_tables WHERE status = 'Свободен'"
    );

    final tablesTotal = await DbService.instance.queryOne(
      'SELECT COUNT(*) as cnt FROM restaurant_tables'
    );

    final activeShifts = await DbService.instance.queryOne(
      "SELECT COUNT(*) as cnt FROM shifts WHERE status = 'Активна'"
    );

    final reservationsToday = await DbService.instance.queryOne(
      "SELECT COUNT(*) as cnt FROM reservations WHERE reservation_date >= ? AND reservation_date < ? AND status != 'Отменено'",
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    final topDishToday = await DbService.instance.queryOne(
      '''
      SELECT d.name, SUM(oi.quantity) as qty
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN dishes d ON d.id = oi.dish_id
      WHERE o.order_date >= ? AND o.order_date < ?
      GROUP BY d.id, d.name
      ORDER BY qty DESC LIMIT 1
      ''',
      arguments: [start.toIso8601String(), end.toIso8601String()],
    );

    return {
      'order_count': todayRow?['order_count'] ?? 0,
      'revenue': todayRow?['revenue'] ?? 0.0,
      'avg_check': todayRow?['avg_check'] ?? 0.0,
      'max_check': todayRow?['max_check'] ?? 0.0,
      'active_orders': activeOrders?['cnt'] ?? 0,
      'tips_today': tipsToday?['total'] ?? 0.0,
      'tables_free': tablesFree?['cnt'] ?? 0,
      'tables_total': tablesTotal?['cnt'] ?? 0,
      'active_shifts': activeShifts?['cnt'] ?? 0,
      'reservations_today': reservationsToday?['cnt'] ?? 0,
      'top_dish': topDishToday?['name'] ?? '—',
    };
  }
}
