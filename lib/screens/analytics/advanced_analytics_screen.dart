import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/discount_repository.dart';
import '../../services/excel_export_service.dart';
import '../../services/backup_service.dart';
import '../../widgets/export_dialog.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  final ReportRepository _reportRepo = const ReportRepository();
  final ExpenseRepository _expenseRepo = const ExpenseRepository();
  final DiscountRepository _discountRepo = const DiscountRepository();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Cached data
  List<Map<String, dynamic>> _dailyRevenue = [];
  Map<String, dynamic> _costAnalysis = {};
  Map<String, dynamic> _menuEngineering = {};
  Map<String, dynamic> _revenueForecast = {};
  Map<String, dynamic> _dayComparison = {};
  Map<String, dynamic> _weekComparison = {};
  Map<String, dynamic> _monthComparison = {};
  Map<String, dynamic> _paymentBreakdown = {};
  Map<String, dynamic> _tableUtilization = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final weekAgo = now.subtract(const Duration(days: 7));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final twoMonthsAgo = DateTime(now.year, now.month - 2, 1);

      final results = await Future.wait([
        _reportRepo.dailyRevenueTrend(startDate: _startDate, endDate: _endDate),
        _reportRepo.costAnalysis(),
        _reportRepo.menuEngineering(),
        _reportRepo.revenueForecast(),
        _reportRepo.dayComparison(yesterday, now),
        _reportRepo.weekComparison(twoWeeksAgo, weekAgo),
        _reportRepo.monthComparison(twoMonthsAgo.year, twoMonthsAgo.month, lastMonth.year, lastMonth.month),
        _reportRepo.paymentMethodBreakdown(),
        _reportRepo.tableUtilization(),
      ]);

      setState(() {
        _dailyRevenue = List<Map<String, dynamic>>.from(results[0] as List);
        _costAnalysis = Map<String, dynamic>.from(results[1] as Map);
        _menuEngineering = Map<String, dynamic>.from(results[2] as Map);
        _revenueForecast = Map<String, dynamic>.from(results[3] as Map);
        _dayComparison = _restructureComparison(Map<String, dynamic>.from(results[4] as Map), 'day1', 'day2');
        _weekComparison = _restructureComparison(Map<String, dynamic>.from(results[5] as Map), 'week1', 'week2');
        _monthComparison = _restructureComparison(Map<String, dynamic>.from(results[6] as Map), 'month1', 'month2');
        _paymentBreakdown = Map<String, dynamic>.from(results[7] as Map);
        _tableUtilization = Map<String, dynamic>.from(results[8] as Map);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadAllData();
    }
  }

  Future<void> _exportToExcel() async {
    final revenue = (_costAnalysis['totalRevenue'] as num?)?.toDouble() ?? 0;
    final avgCheck = (_costAnalysis['avg_check'] as num?)?.toDouble() ?? 0;

    await showExportDialog(
      context,
      title: 'Экспорт аналитики',
      actions: [
        ExportAction(
          label: 'Экспорт в Excel',
          icon: Icons.table_chart,
          extension: 'xlsx',
          generateData: () async {
            final service = ExcelExportService();
            final path = await service.exportReport(
              startDate: _startDate,
              endDate: _endDate,
              revenue: revenue,
              averageCheck: avgCheck,
              maximumCheck: 0.0,
              minimumCheck: 0.0,
              hourlyLoad: [],
              topDishes: (_menuEngineering['dishes'] as List?)?.cast<Map<String, dynamic>>() ?? [],
            );
            return File(path).readAsBytes();
          },
        ),
        ExportAction(
          label: 'Экспорт в CSV',
          icon: Icons.description,
          extension: 'csv',
          generateData: () async {
            final headers = <String>['Показатель', 'Значение'];
            final rows = <List<dynamic>>[
              ['Выручка', _formatCurrency(revenue)],
              ['Средний чек', _formatCurrency(avgCheck)],
              ['Себестоимость %', '${(_costAnalysis['foodCostPercentage'] as num?)?.toDouble()?.toStringAsFixed(1) ?? '0'}%'],
              ['Операц. расходы', _formatCurrency((_costAnalysis['operatingExpenses'] as num?)?.toDouble() ?? 0)],
              ['Чистая прибыль', _formatCurrency((_costAnalysis['netProfit'] as num?)?.toDouble() ?? 0)],
              ['Маржа %', '${(_costAnalysis['profitMargin'] as num?)?.toDouble()?.toStringAsFixed(1) ?? '0'}%'],
            ];
            return Uint8List.fromList(generateCsv(headers, rows).codeUnits);
          },
        ),
        ExportAction(
          label: 'Экспорт в SQL',
          icon: Icons.code,
          extension: 'sql',
          generateData: () async {
            final content = await const BackupService().exportFullData();
            return Uint8List.fromList(content.codeUnits);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Аналитика'),
          actions: [
            IconButton(
              icon: const Icon(Icons.table_chart),
              tooltip: 'Экспорт в Excel',
              onPressed: _exportToExcel,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Обзор', icon: Icon(Icons.dashboard)),
              Tab(text: 'Меню', icon: Icon(Icons.restaurant_menu)),
              Tab(text: 'Сравнения', icon: Icon(Icons.compare_arrows)),
              Tab(text: 'Прогнозы', icon: Icon(Icons.trending_up)),
              Tab(text: 'Столики', icon: Icon(Icons.table_restaurant)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildOverviewTab(theme),
                  _buildMenuEngineeringTab(theme),
                  _buildComparisonsTab(theme),
                  _buildForecastsTab(theme),
                  _buildTablesTab(theme),
                ],
              ),
      ),
    );
  }

  // ─── TAB 1: Overview ───────────────────────────────────────────────
  Widget _buildOverviewTab(ThemeData theme) {
    final revenue = (_costAnalysis['totalRevenue'] as num?)?.toDouble() ?? 0;
    final foodCostPct = (_costAnalysis['foodCostPercentage'] as num?)?.toDouble() ?? 0;
    final operatingExpenses = (_costAnalysis['operatingExpenses'] as num?)?.toDouble() ?? 0;
    final netProfit = (_costAnalysis['netProfit'] as num?)?.toDouble() ?? 0;
    final profitMargin = (_costAnalysis['profitMargin'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildDateRangePicker(theme),
          const SizedBox(height: 12),
          _buildMetricCards(theme, revenue, foodCostPct, operatingExpenses, netProfit, profitMargin),
          const SizedBox(height: 16),
          Text('Тренд выручки по дням', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDailyRevenueList(theme),
          const SizedBox(height: 16),
          Text('Способы оплаты', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildPaymentBreakdown(theme),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.date_range, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _pickDate(isStart: true),
              child: Text('С: ${_formatDate(_startDate)}'),
            ),
            const Icon(Icons.arrow_forward, size: 16),
            TextButton(
              onPressed: () => _pickDate(isStart: false),
              child: Text('По: ${_formatDate(_endDate)}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCards(
    ThemeData theme,
    double revenue,
    double foodCostPct,
    double operatingExpenses,
    double netProfit,
    double profitMargin,
  ) {
    final cards = [
      _MetricData('Выручка', revenue, Icons.attach_money, Colors.green),
      _MetricData('Себестоимость %', foodCostPct, Icons.pie_chart, Colors.orange),
      _MetricData('Операц. расходы', operatingExpenses, Icons.receipt_long, Colors.red),
      _MetricData('Чистая прибыль', netProfit, Icons.account_balance, Colors.blue),
      _MetricData('Маржа %', profitMargin, Icons.percent, Colors.purple),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cards.map((m) {
        final isNegative = m.value < 0;
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 36) / 2,
          child: Card(
            color: m.color.withAlpha(30),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(m.icon, color: m.color, size: 28),
                  const SizedBox(height: 4),
                  Text(m.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    m.label.contains('%')
                        ? '${m.value.toStringAsFixed(1)}%'
                        : _formatCurrency(m.value),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isNegative ? Colors.red : m.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDailyRevenueList(ThemeData theme) {
    if (_dailyRevenue.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Нет данных')));
    }

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: theme.colorScheme.primary.withAlpha(25),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Дата', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Заказы', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('Выручка', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          ..._dailyRevenue.take(30).map((day) {
            final date = DateTime.parse(day['date']?.toString() ?? DateTime.now().toIso8601String());
            final orders = day['orderCount'] ?? 0;
            final rev = (day['revenue'] as num?)?.toDouble() ?? 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(30))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(_formatDate(date), style: theme.textTheme.bodyMedium),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$orders', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(_formatCurrency(rev), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(ThemeData theme) {
    final methods = _paymentBreakdown['methods'] as List<dynamic>? ?? [];

    if (methods.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Нет данных')));
    }

    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: methods.asMap().entries.map((entry) {
            final idx = entry.key;
            final method = entry.value;
            final name = method['name']?.toString() ?? 'Неизвестно';
            final amount = (method['amount'] as num?)?.toDouble() ?? 0;
            final pct = (method['percentage'] as num?)?.toDouble() ?? 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(width: 14, height: 14, color: colors[idx % colors.length]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name)),
                  SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      value: pct / 100,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colors[idx % colors.length]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 50, child: Text('${pct.toStringAsFixed(0)}%', textAlign: TextAlign.right)),
                  const SizedBox(width: 8),
                  SizedBox(width: 100, child: Text(_formatCurrency(amount), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── TAB 2: Menu Engineering ──────────────────────────────────────
  Widget _buildMenuEngineeringTab(ThemeData theme) {
    final stars = _menuEngineering['stars'] as List<dynamic>? ?? [];
    final puzzles = _menuEngineering['puzzles'] as List<dynamic>? ?? [];
    final dogs = _menuEngineering['dogs'] as List<dynamic>? ?? [];
    final workhorses = _menuEngineering['workhorses'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              _quadrantLegend('⭐ Звезда', Colors.green),
              const SizedBox(width: 8),
              _quadrantLegend('❓ Загадка', Colors.amber),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _quadrantLegend('🐕 Собака', Colors.red),
              const SizedBox(width: 8),
              _quadrantLegend('🐄 Рабочая лошадка', Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuadrantCard(theme, '⭐ Звезда — высокая маржа, высокий спрос', Colors.green, stars),
          _buildQuadrantCard(theme, '❓ Загадка — высокая маржа, низкий спрос', Colors.amber, puzzles),
          _buildQuadrantCard(theme, '🐕 Собака — низкая маржа, низкий спрос', Colors.red, dogs),
          _buildQuadrantCard(theme, '🐄 Рабочая лошадка — низкая маржа, высокий спрос', Colors.blue, workhorses),
        ],
      ),
    );
  }

  Widget _quadrantLegend(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildQuadrantCard(ThemeData theme, String title, Color color, List<dynamic> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Нет блюд в этой категории', style: TextStyle(color: Colors.grey)),
            )
          else
            ...items.map((dish) {
              final name = dish['name']?.toString() ?? '';
              final qty = dish['quantitySold'] ?? 0;
              final dishRevenue = (dish['revenue'] as num?)?.toDouble() ?? 0;
              final margin = (dish['margin'] as num?)?.toDouble() ?? 0;

              return GestureDetector(
                onTap: () => _showDishDetail(name, qty, dishRevenue, margin, title, color),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(20))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 32,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('Кол-во', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Выручка', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                            Text(_formatCurrency(dishRevenue), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Маржа', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                            Text('${margin.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showDishDetail(String name, dynamic qty, double revenue, double margin, String quadrant, Color color) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(quadrant, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 20),
            _dishDetailRow('Продано', '$qty шт.'),
            _dishDetailRow('Выручка', _formatCurrency(revenue)),
            _dishDetailRow('Маржа', '${margin.toStringAsFixed(1)}%'),
            _dishDetailRow('Классификация', quadrant.split('—').first.trim()),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _dishDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.grey)),
          Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── TAB 3: Comparisons ──────────────────────────────────────────
  Widget _buildComparisonsTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildComparisonCard(theme, 'День vs День', Icons.today, _dayComparison),
          const SizedBox(height: 12),
          _buildComparisonCard(theme, 'Неделя vs Неделя', Icons.view_week, _weekComparison),
          const SizedBox(height: 12),
          _buildComparisonCard(theme, 'Месяц vs Месяц', Icons.calendar_month, _monthComparison),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(ThemeData theme, String title, IconData icon, Map<String, dynamic> data) {
    final current = (data['current'] as num?)?.toDouble() ?? 0;
    final previous = (data['previous'] as num?)?.toDouble() ?? 0;
    final change = (data['changePercentage'] as num?)?.toDouble() ?? 0;
    final isGrowing = change >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGrowing ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGrowing ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: isGrowing ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isGrowing ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _comparisonStatBlock(theme, 'Текущий период', current),
                ),
                Container(width: 1, height: 50, color: theme.colorScheme.outline),
                Expanded(
                  child: _comparisonStatBlock(theme, 'Пред. период', previous),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonStatBlock(ThemeData theme, String label, double value) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(value),
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Map<String, dynamic> _restructureComparison(Map<String, dynamic> raw, String key1, String key2) {
    final period1 = raw[key1] as Map? ?? {};
    final period2 = raw[key2] as Map? ?? {};
    final current = (period1['revenue'] as num?)?.toDouble() ?? 0;
    final previous = (period2['revenue'] as num?)?.toDouble() ?? 0;
    final changePercentage = previous > 0 ? ((current - previous) / previous * 100) : 0;
    return {'current': current, 'previous': previous, 'changePercentage': changePercentage};
  }

  // ─── TAB 4: Forecasts ────────────────────────────────────────────
  Widget _buildForecastsTab(ThemeData theme) {
    final forecastList = _revenueForecast['forecast'] as List<dynamic>? ?? [];
    final trendValue = (_revenueForecast['trend'] as num?)?.toDouble() ?? 0;
    final avgDaily = (_revenueForecast['avg_daily'] as num?)?.toDouble() ?? 0;
    final recent7 = (_revenueForecast['recent_avg'] as num?)?.toDouble() ?? 0;

    final trend = trendValue > 2 ? 'growing' : trendValue < -2 ? 'declining' : 'stable';
    final trendColor = trend == 'growing' ? Colors.green : trend == 'declining' ? Colors.red : Colors.orange;
    final trendIcon = trend == 'growing' ? Icons.trending_up : trend == 'declining' ? Icons.trending_down : Icons.trending_flat;
    final trendLabel = trend == 'growing' ? 'Растущий' : trend == 'declining' ? 'Убывающий' : 'Стабильный';

    final totalForecast = forecastList.fold<double>(0, (sum, day) {
      final d = day as Map<String, dynamic>;
      return sum + ((d['predicted_revenue'] as num?)?.toDouble() ?? 0);
    });

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(trendIcon, size: 48, color: trendColor),
                  const SizedBox(height: 8),
                  Text('Тренд: $trendLabel', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: trendColor)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _forecastMetric(theme, 'Прогноз (30 дн)', totalForecast)),
                      Expanded(child: _forecastMetric(theme, 'Средняя/день', avgDaily)),
                      Expanded(child: _forecastMetric(theme, 'Средн. 7 дн', recent7)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Прогноз по дням', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (forecastList.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Нет данных прогноза')))
          else
            Card(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: theme.colorScheme.primary.withAlpha(25),
                    child: Row(
                      children: [
                        Expanded(flex: 4, child: Text('Дата', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold))),
                        Expanded(flex: 4, child: Text('Прогноз', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  ...forecastList.map((day) {
                    final d = day as Map<String, dynamic>;
                    final date = DateTime.parse(d['date']?.toString() ?? DateTime.now().toIso8601String());
                    final dayForecast = (d['predicted_revenue'] as num?)?.toDouble() ?? 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(20))),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text(_formatDate(date), style: const TextStyle(fontSize: 12))),
                          Expanded(flex: 4, child: Text(_formatCurrency(dayForecast), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _forecastMetric(ThemeData theme, String label, double value) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(_formatCurrency(value), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── TAB 5: Tables ───────────────────────────────────────────────
  Widget _buildTablesTab(ThemeData theme) {
    final utilization = (_tableUtilization['utilizationRate'] as num?)?.toDouble() ?? 0;
    final totalTables = _tableUtilization['totalTables'] ?? 0;
    final mostProfitable = _tableUtilization['mostProfitable'] as List<dynamic>? ?? [];
    final zoneBreakdown = _tableUtilization['zones'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: utilization / 100,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(
                              utilization > 80 ? Colors.green : utilization > 50 ? Colors.orange : Colors.red,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${utilization.toStringAsFixed(0)}%', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            Text('загрузка', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Всего столов: $totalTables', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Самые прибыльные столики', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildMostProfitableTables(theme, mostProfitable),
          const SizedBox(height: 16),
          Text('Зоны ресторана', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildZoneBreakdown(theme, zoneBreakdown),
        ],
      ),
    );
  }

  Widget _buildMostProfitableTables(ThemeData theme, List<dynamic> tables) {
    if (tables.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Нет данных')));
    }

    final medals = [Colors.amber, Colors.grey, Color(0xFFCD7F32)];
    final medalIcons = ['🥇', '🥈', '🥉'];

    return Card(
      child: Column(
        children: tables.asMap().entries.map((entry) {
          final idx = entry.key;
          final table = entry.value;
          final number = table['tableNumber'] ?? idx + 1;
          final revenue = (table['revenue'] as num?)?.toDouble() ?? 0;
          final orders = table['orderCount'] ?? 0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(20))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: idx < 3 ? Text(medalIcons[idx], style: const TextStyle(fontSize: 18)) : Text('#${idx + 1}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Столик #$number', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('$orders заказов', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text(_formatCurrency(revenue), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildZoneBreakdown(ThemeData theme, List<dynamic> zones) {
    if (zones.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Нет данных')));
    }

    final zoneColors = [Colors.teal, Colors.indigo, Colors.brown, Colors.pink, Colors.cyan];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: zones.asMap().entries.map((entry) {
            final idx = entry.key;
            final zone = entry.value;
            final name = zone['name']?.toString() ?? 'Зона ${idx + 1}';
            final tables = zone['tableCount'] ?? 0;
            final revenue = (zone['revenue'] as num?)?.toDouble() ?? 0;
            final utilization = (zone['utilization'] as num?)?.toDouble() ?? 0;
            final color = zoneColors[idx % zoneColors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('$tables столов'),
                      const SizedBox(width: 12),
                      Text(_formatCurrency(revenue), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 22),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: utilization / 100,
                            minHeight: 6,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 40, child: Text('${utilization.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatCurrency(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M ₽';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K ₽';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }
}

class _MetricData {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _MetricData(this.label, this.value, this.icon, this.color);
}
