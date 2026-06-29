import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../repositories/report_repository.dart';

class ProfitLossScreen extends StatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  final ReportRepository repository = const ReportRepository();

  late DateTime startDate;
  late DateTime endDate;

  Map<String, dynamic>? data;
  bool loading = true;
  int _selectedPeriod = 3;

  static const _periods = [
    _PeriodOption('Сегодня', 0),
    _PeriodOption('Вчера', 1),
    _PeriodOption('Эта неделя', 2),
    _PeriodOption('Этот месяц', 3),
    _PeriodOption('Произвольный', 4),
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
          break;
      }
    });
    _loadData();
  }

  DateTime get _queryStart =>
      DateTime(startDate.year, startDate.month, startDate.day);
  DateTime get _queryEnd => DateTime(endDate.year, endDate.month, endDate.day);

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
      _selectedPeriod = 4;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      data = await repository.profitAndLoss(_queryStart, _queryEnd);
    } catch (e) {
      debugPrint('P&L error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      );
    }
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: cs.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPeriodSelector(cs),
            const SizedBox(height: 16),
            _buildRevenueCard(cs),
            const SizedBox(height: 16),
            _buildExpensesCard(cs),
            const SizedBox(height: 16),
            _buildProfitCard(cs),
            const SizedBox(height: 16),
            _buildCostBreakdownChart(cs),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(ColorScheme cs) {
    return Card(
      color: cs.surface,
      surfaceTintColor: cs.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Период отчёта',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_periods.length, (i) {
                final p = _periods[i];
                final sel = _selectedPeriod == i;
                return ChoiceChip(
                  label: Text(p.label,
                      style: TextStyle(
                          fontSize: 13,
                          color: sel
                              ? cs.onPrimary
                              : cs.onSurface)),
                  selected: sel,
                  selectedColor: cs.primary,
                  backgroundColor: cs.surfaceContainerHighest,
                  onSelected: (_) => _applyPeriod(i),
                );
              }),
            ),
            if (_selectedPeriod == 4) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('С ${_formatDate(startDate)}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('По ${_formatDate(endDate)}',
                          style: const TextStyle(fontSize: 12)),
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

  Widget _buildRevenueCard(ColorScheme cs) {
    final revenue = (data?['revenue'] as num?)?.toDouble() ?? 0;
    final cogs = (data?['cogs'] as num?)?.toDouble() ?? 0;
    final grossProfit = (data?['gross_profit'] as num?)?.toDouble() ?? 0;
    final grossMargin = (data?['gross_margin'] as num?)?.toDouble() ?? 0;
    final orderCount = (data?['order_count'] as num?)?.toInt() ?? 0;
    final avgCheck = (data?['avg_check'] as num?)?.toDouble() ?? 0;

    return Card(
      color: cs.surface,
      surfaceTintColor: cs.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Выручка и валовая прибыль',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow('Выручка', '${_fmt(revenue)} ₽', cs.primary, cs),
            _infoRow('Заказов', '$orderCount', cs.onSurface, cs),
            _infoRow('Средний чек', '${_fmt(avgCheck)} ₽', cs.onSurface, cs),
            const Divider(height: 20),
            _infoRow('Себестоимость (COGS)', '${_fmt(cogs)} ₽', cs.tertiary, cs),
            _infoRow('Валовая прибыль', '${_fmt(grossProfit)} ₽',
                grossProfit >= 0 ? cs.primary : cs.error, cs),
            _infoRow('Валовая маржа', '${grossMargin.toStringAsFixed(1)}%',
                grossMargin >= 0 ? cs.primary : cs.error, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesCard(ColorScheme cs) {
    final labor = (data?['labor'] as num?)?.toDouble() ?? 0;
    final opex = (data?['opex'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (data?['total_expenses'] as num?)?.toDouble() ?? 0;

    return Card(
      color: cs.surface,
      surfaceTintColor: cs.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: cs.secondary, size: 20),
                const SizedBox(width: 8),
                Text('Операционные расходы',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow('ФОТ (зарплата)', '${_fmt(labor)} ₽', cs.secondary, cs),
            _infoRow('Прочие расходы', '${_fmt(opex)} ₽', cs.tertiary, cs),
            const Divider(height: 20),
            _infoRow('Всего расходов', '${_fmt(totalExpenses)} ₽', cs.onSurface, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitCard(ColorScheme cs) {
    final netProfit = (data?['net_profit'] as num?)?.toDouble() ?? 0;
    final netMargin = (data?['net_margin'] as num?)?.toDouble() ?? 0;
    final profitColor = netProfit >= 0 ? cs.primary : cs.error;

    return Card(
      color: profitColor.withValues(alpha: 0.05),
      surfaceTintColor: cs.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    netProfit >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: profitColor,
                    size: 28),
                const SizedBox(width: 12),
                Text('Чистая прибыль / убыток',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${_fmt(netProfit)} ₽',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: profitColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Чистая маржа: ${netMargin.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostBreakdownChart(ColorScheme cs) {
    final revenue = (data?['revenue'] as num?)?.toDouble() ?? 0;
    final cogs = (data?['cogs'] as num?)?.toDouble() ?? 0;
    final labor = (data?['labor'] as num?)?.toDouble() ?? 0;
    final opex = (data?['opex'] as num?)?.toDouble() ?? 0;
    final netProfit = (data?['net_profit'] as num?)?.toDouble() ?? 0;

    if (revenue == 0) return const SizedBox.shrink();

    final cogsPct = cogs / revenue;
    final laborPct = labor / revenue;
    final opexPct = opex / revenue;
    final profitPct = netProfit / revenue;

    return Card(
      color: cs.surface,
      surfaceTintColor: cs.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Структура выручки',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.center,
                  maxY: revenue,
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(
                        toY: cogs,
                        color: cs.tertiary,
                        width: 48,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(0)),
                      ),
                      BarChartRodData(
                        fromY: cogs,
                        toY: cogs + labor,
                        color: cs.secondary,
                        width: 48,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(0)),
                      ),
                      BarChartRodData(
                        fromY: cogs + labor,
                        toY: cogs + labor + opex,
                        color: cs.outlineVariant,
                        width: 48,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(0)),
                      ),
                      BarChartRodData(
                        fromY: cogs + labor + opex,
                        toY: revenue,
                        color: cs.primary,
                        width: 48,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ]),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final labels = ['COGS', 'ФОТ', 'Расходы', 'Прибыль'];
                        final amounts = [cogs, labor, opex, netProfit];
                        final pcts = [
                          cogsPct,
                          laborPct,
                          opexPct,
                          profitPct
                        ];
                        return BarTooltipItem(
                          '${labels[rodIndex]}\n${_fmt(amounts[rodIndex])} ₽ (${(pcts[rodIndex] * 100).toStringAsFixed(1)}%)',
                          TextStyle(
                              color: cs.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 300),
              ),
            ),
            const SizedBox(height: 16),
            _legendRow(cs, cs.tertiary, 'COGS',
                '${(cogsPct * 100).toStringAsFixed(0)}%'),
            _legendRow(cs, cs.secondary, 'ФОТ',
                '${(laborPct * 100).toStringAsFixed(0)}%'),
            _legendRow(cs, cs.outlineVariant, 'Прочие расходы',
                '${(opexPct * 100).toStringAsFixed(0)}%'),
            _legendRow(cs, cs.primary, 'Чистая прибыль',
                '${(profitPct * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      String label, String value, Color valueColor, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: cs.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }

  Widget _legendRow(
      ColorScheme cs, Color color, String label, String pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurface))),
          Text(pct,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
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
