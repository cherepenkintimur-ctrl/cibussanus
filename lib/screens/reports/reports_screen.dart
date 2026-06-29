import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../database/db_service.dart';
import '../../models/converters.dart';
import '../../repositories/report_repository.dart';
import '../../services/excel_export_service.dart';
import '../../services/backup_service.dart';
import '../../widgets/charts.dart';
import '../../widgets/export_dialog.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportRepository repository = const ReportRepository();
  final excelService = const ExcelExportService();

  late DateTime startDate;
  late DateTime endDate;

  double revenue = 0;
  double averageCheck = 0;
  double maximumCheck = 0;
  int orderCount = 0;
  double totalCost = 0;
  double netProfit = 0;
  double profitMargin = 0;
  double foodCostPercent = 0;

  List<Map<String, dynamic>> dailyRevenue = [];
  List<Map<String, dynamic>> topDishes = [];
  List<Map<String, dynamic>> hourlyLoad = [];
  List<Map<String, dynamic>> paymentMethods = [];

  bool loading = true;
  int _selectedPeriod = 3;

  static const _paymentColors = [
    Color(0xFF6B1520), Color(0xFFC9A96E), Color(0xFFD4A574),
    Color(0xFF2E7D32), Color(0xFFE65100),
  ];

  static const _periods = [
    _PeriodOption('Сегодня', 0),
    _PeriodOption('Вчера', 1),
    _PeriodOption('Эта неделя', 2),
    _PeriodOption('Этот месяц', 3),
    _PeriodOption('Прошлый месяц', 4),
    _PeriodOption('3 месяца', 5),
    _PeriodOption('Произвольный', 6),
  ];

  @override
  void initState() {
    super.initState();
    endDate = DateTime.now();
    startDate = DateTime.now().subtract(const Duration(days: 30));
    _applyPeriod(3);
  }

  void _applyPeriod(int index) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _selectedPeriod = index;
      switch (index) {
        case 0:
          startDate = today;
          endDate = now;
          break;
        case 1:
          startDate = today.subtract(const Duration(days: 1));
          endDate = today;
          break;
        case 2:
          startDate = today.subtract(Duration(days: today.weekday - 1));
          endDate = now;
          break;
        case 3:
          startDate = DateTime(now.year, now.month, 1);
          endDate = now;
          break;
        case 4:
          final prevMonth = DateTime(now.year, now.month - 1, 1);
          startDate = prevMonth;
          endDate = DateTime(now.year, now.month, 1);
          break;
        case 5:
          startDate = DateTime(now.year, now.month - 3, now.day);
          endDate = now;
          break;
        case 6:
          break;
      }
    });
    loadReport();
  }

  DateTime get _queryStart =>
      DateTime(startDate.year, startDate.month, startDate.day);

  DateTime get _queryEnd {
    if (_selectedPeriod == 1 || _selectedPeriod == 4) {
      return DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));
    }
    return DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? startDate : endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        startDate = picked;
        if (startDate.isAfter(endDate)) endDate = startDate;
      } else {
        endDate = picked;
        if (endDate.isBefore(startDate)) startDate = endDate;
      }
      _selectedPeriod = 6;
    });
  }

  Future<void> loadReport() async {
    setState(() => loading = true);

    try {
      final start = _queryStart;
      final end = _queryEnd;

      final revenueData = await repository.revenueByPeriod(startDate: start, endDate: end);
      revenue = revenueData;

      final stats = await repository.checkStatisticsByPeriod(startDate: start, endDate: end);
      averageCheck = stats['average_check'] ?? 0;
      maximumCheck = stats['maximum_check'] ?? 0;

      final orderCountRow = await DbService.instance.queryOne(
        'SELECT COUNT(*) as cnt FROM orders WHERE order_date >= ? AND order_date < ?',
        arguments: [start.toIso8601String(), end.toIso8601String()],
      );
      orderCount = parseInt(orderCountRow?['cnt']) ?? 0;

      final costData = await repository.costAnalysis(startDate: start, endDate: end);
      totalCost = costData['total_costs'] ?? 0;
      netProfit = costData['net_profit'] ?? 0;
      profitMargin = costData['profit_margin'] ?? 0;
      foodCostPercent = costData['food_cost_percent'] ?? 0;

      dailyRevenue = await repository.dailyRevenueTrend(startDate: start, endDate: end);
      topDishes = await repository.topDishesByPeriod(startDate: start, endDate: end, limit: 15);
      hourlyLoad = await repository.hourlyLoadByPeriod(startDate: start, endDate: end);
      paymentMethods = List<Map<String, dynamic>>.from((await repository.paymentMethodBreakdown(startDate: start, endDate: end))['methods'] ?? []);
    } catch (e) {
      debugPrint('Report error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _exportToExcel() async {
    await showExportDialog(
      context,
      title: 'Экспорт отчёта',
      actions: [
        ExportAction(
          label: 'Экспорт в Excel',
          icon: Icons.table_chart,
          extension: 'xlsx',
          generateData: () async {
            final path = await excelService.exportReport(
              startDate: startDate,
              endDate: endDate,
              revenue: revenue,
              averageCheck: averageCheck,
              maximumCheck: maximumCheck,
              minimumCheck: 0,
              hourlyLoad: hourlyLoad,
              topDishes: topDishes,
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
              ['Выручка', '${_fmt(revenue)} ₽'],
              ['Средний чек', '${_fmt(averageCheck)} ₽'],
              ['Макс. чек', '${_fmt(maximumCheck)} ₽'],
              ['Заказов', orderCount.toString()],
              ['Прибыль', '${_fmt(netProfit)} ₽'],
              ['Маржа', '${profitMargin.toStringAsFixed(1)}%'],
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
    if (loading) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'export_report',
        onPressed: _exportToExcel,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.download),
        label: const Text('Экспорт Excel'),
      ),
      body: RefreshIndicator(
        onRefresh: loadReport,
        color: Theme.of(context).colorScheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildMetricsGrid(),
            const SizedBox(height: 20),
            _buildRevenueChart(),
            const SizedBox(height: 20),
            _buildPaymentPieChart(),
            const SizedBox(height: 20),
            _buildTopDishes(),
            const SizedBox(height: 20),
            _buildHourlyHeatmap(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Период отчёта', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_periods.length, (i) {
                final p = _periods[i];
                final sel = _selectedPeriod == i;
                return ChoiceChip(
                  label: Text(p.label, style: TextStyle(fontSize: 13, color: sel ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                  selected: sel,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  onSelected: (_) => _applyPeriod(i),
                );
              }),
            ),
            if (_selectedPeriod == 6) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('С ${_formatDate(startDate)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('По ${_formatDate(endDate)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _metricCard('Выручка', '${_fmt(revenue)} ₽', Icons.payments_rounded, const Color(0xFF2E7D32)),
        _metricCard('Заказов', '$orderCount', Icons.receipt_long_rounded, const Color(0xFF6B1520)),
        _metricCard('Средний чек', '${_fmt(averageCheck)} ₽', Icons.trending_up_rounded, const Color(0xFFC9A96E)),
        _metricCard('Макс. чек', '${_fmt(maximumCheck)} ₽', Icons.star_rounded, const Color(0xFFE65100)),
        _metricCard('Прибыль', '${_fmt(netProfit)} ₽', Icons.account_balance_wallet_rounded, netProfit >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
        _metricCard('Маржа', '${profitMargin.toStringAsFixed(1)}%', Icons.pie_chart_rounded, const Color(0xFF4A148C)),
        _metricCard('Себестоимость', '${foodCostPercent.toStringAsFixed(1)}%', Icons.inventory_rounded, const Color(0xFFBF360C)),
        _metricCard('Расходы', '${_fmt(totalCost)} ₽', Icons.money_off_rounded, const Color(0xFFC9A96E)),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _showMetricDetail(label, value, icon, color),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetricDetail(String label, String value, IconData icon, Color color) {
    final details = {
      'Выручка': 'Общая сумма выручки за выбранный период. Включает все оплаченные заказы.',
      'Заказов': 'Общее количество оформленных и оплаченных заказов за период.',
      'Средний чек': 'Средняя сумма одного заказа. Рассчитывается как выручка / количество заказов.',
      'Макс. чек': 'Максимальная сумма одного заказа за выбранный период.',
      'Прибыль': 'Чистая прибыль: выручка минус себестоимость и расходы.',
      'Маржа': 'Процент маржинальности: доля прибыли в выручке.',
      'Себестоимость': 'Процент себестоимости блюд от выручки. Чем ниже — тем лучше.',
      'Расходы': 'Сумма всех расходов за выбранный период.',
    };
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(details[label] ?? '', style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    if (dailyRevenue.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выручка по дням', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: RevenueLineChart(data: dailyRevenue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPieChart() {
    if (paymentMethods.isEmpty) return const SizedBox.shrink();

    final totalPay = paymentMethods.fold<double>(0, (s, m) => s + parseDouble(m['total']));
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < paymentMethods.length; i++) {
      final m = paymentMethods[i];
      final total = parseDouble(m['total']);
      final pct = totalPay > 0 ? (total / totalPay * 100) : 0;
      sections.add(PieChartSectionData(
        color: _paymentColors[i % _paymentColors.length],
        value: total,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: null,
        titlePositionPercentageOffset: 0.55,
      ));
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Оплата по методам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: PieChart(PieChartData(
                    sections: sections,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent && response?.touchedSection != null) {
                          final idx = response!.touchedSection!.touchedSectionIndex;
                          _showPaymentDetail(idx);
                        }
                      },
                    ),
                  )),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(paymentMethods.length, (i) {
                      final m = paymentMethods[i];
                      final total = parseDouble(m['total']);
                      final count = parseInt(m['count']) ?? 0;
                      return GestureDetector(
                        onTap: () => _showPaymentDetail(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: _paymentColors[i % _paymentColors.length], borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 8),
                              Expanded(child: Text(m['method']?.toString() ?? '', style: const TextStyle(fontSize: 13))),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${_fmt(total)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('$count заказов', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetail(int index) {
    if (index < 0 || index >= paymentMethods.length) return;
    final m = paymentMethods[index];
    final total = parseDouble(m['total']);
    final count = parseInt(m['count']) ?? 0;
    final totalPay = paymentMethods.fold<double>(0, (s, p) => s + parseDouble(p['total']));
    final pct = totalPay > 0 ? (total / totalPay * 100) : 0;

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
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: _paymentColors[index % _paymentColors.length], borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 10),
                Text(m['method']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            _paymentDetailRow('Общая сумма', '${_fmt(total)} ₽'),
            _paymentDetailRow('Количество заказов', '$count'),
            _paymentDetailRow('Доля от выручки', '${pct.toStringAsFixed(1)}%'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _paymentDetailRow(String label, String val) {
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

  Widget _buildTopDishes() {
    if (topDishes.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Топ блюд по продажам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                const Spacer(),
                Text('${topDishes.length} позиций', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            _dishTableHeader(),
            const Divider(height: 1),
            ...List.generate(topDishes.length, (i) {
              final d = topDishes[i];
              final qty = parseInt(d['quantity_sold']) ?? 0;
              final rev = parseDouble(d['revenue']);
              final margin = parseDouble(d['margin_percent']);
              final maxQty = parseInt(topDishes.first['quantity_sold']) ?? 1;
              final barWidth = maxQty > 0 ? (qty / maxQty) : 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: i % 2 == 0
                      ? (theme.brightness == Brightness.dark
                          ? Colors.grey[900]
                          : const Color(0xFFFFF8F0))
                      : theme.cardColor,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                          SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.primary))),
                        Expanded(flex: 3, child: Text(d['dish_name']?.toString() ?? '', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Expanded(flex: 1, child: Text('$qty шт', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('${_fmt(rev)} ₽', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)))),
                        Expanded(flex: 1, child: Text('${margin.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: margin >= 50 ? const Color(0xFF2E7D32) : margin >= 30 ? const Color(0xFFE65100) : const Color(0xFFC62828)))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: barWidth.toDouble(),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(margin >= 50 ? const Color(0xFF2E7D32) : margin >= 30 ? const Color(0xFFE65100) : const Color(0xFFC62828)),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _dishTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
          const Expanded(flex: 3, child: Text('Блюдо', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
          const Expanded(flex: 1, child: Text('Кол-во', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
          const Expanded(flex: 1, child: Text('Выручка', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
          const Expanded(flex: 1, child: Text('Маржа', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildHourlyHeatmap() {
    if (hourlyLoad.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Загруженность по часам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showHourlyOverview,
              child: SizedBox(
                height: 160,
                child: HourlyBarChart(data: hourlyLoad),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHourlyOverview() {
    if (hourlyLoad.isEmpty) return;
    final maxEntry = hourlyLoad.reduce((a, b) =>
        ((a['orders_count'] as num) ?? 0) >= ((b['orders_count'] as num) ?? 0) ? a : b);
    final minEntry = hourlyLoad.reduce((a, b) =>
        ((a['orders_count'] as num) ?? 0) <= ((b['orders_count'] as num) ?? 0) ? a : b);
    final totalOrders = hourlyLoad.fold<int>(0, (s, e) => s + ((e['orders_count'] as num?)?.toInt() ?? 0));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Загруженность по часам', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _hourlyDetailRow('Всего заказов', '$totalOrders'),
            _hourlyDetailRow('Пиковый час', _formatHour(maxEntry)),
            _hourlyDetailRow('Заказов на пике', '${maxEntry['orders_count']}'),
            _hourlyDetailRow('Мин. загрузка', _formatHour(minEntry)),
            _hourlyDetailRow('Заказов в минимуме', '${minEntry['orders_count']}'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatHour(Map<String, dynamic> entry) {
    final hour = entry['hour'];
    if (hour is int) return '${hour.toString().padLeft(2, '0')}:00';
    return hour?.toString() ?? '';
  }

  Widget _hourlyDetailRow(String label, String val) {
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

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _PeriodOption {
  final String label;
  final int index;
  const _PeriodOption(this.label, this.index);
}
