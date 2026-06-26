import 'package:flutter/material.dart';

import '../../models/converters.dart';
import '../../repositories/report_repository.dart';
import '../../services/excel_export_service.dart';

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
  double minimumCheck = 0;

  List<Map<String, dynamic>> hourlyLoad = [];
  List<Map<String, dynamic>> topDishes = [];

  bool loading = true;
  String? errorText;

  @override
  void initState() {
    super.initState();
    endDate = DateTime.now();
    startDate = DateTime.now().subtract(const Duration(days: 30));
    loadReport();
  }

  DateTime get _queryStart =>
      DateTime(startDate.year, startDate.month, startDate.day);

  DateTime get _queryEnd =>
      DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? startDate : endDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        startDate = picked;
        if (startDate.isAfter(endDate)) {
          endDate = startDate;
        }
      } else {
        endDate = picked;
        if (endDate.isBefore(startDate)) {
          startDate = endDate;
        }
      }
    });
  }

  Future<void> loadReport() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      revenue = await repository.revenueByPeriod(
        startDate: _queryStart,
        endDate: _queryEnd,
      );

      final stats = await repository.checkStatisticsByPeriod(
        startDate: _queryStart,
        endDate: _queryEnd,
      );

      averageCheck = stats['average_check'] ?? 0;
      maximumCheck = stats['maximum_check'] ?? 0;
      minimumCheck = stats['minimum_check'] ?? 0;

      final load = await repository.hourlyLoadByPeriod(
        startDate: _queryStart,
        endDate: _queryEnd,
      );

      final byHour = <int, Map<String, dynamic>>{};
      for (final row in load) {
        final hour = parseInt(row['hour']) ?? 0;
        byHour[hour] = row;
      }

      hourlyLoad = List.generate(24, (hour) {
        final row = byHour[hour];
        return {
          'hour': hour,
          'orders_count': row == null ? 0 : parseInt(row['orders_count']) ?? 0,
          'revenue': row == null ? 0.0 : parseDouble(row['revenue']),
        };
      });

      topDishes = await repository.topDishesByPeriod(
        startDate: _queryStart,
        endDate: _queryEnd,
        limit: 10,
      );
    } catch (e) {
      errorText = 'Ошибка формирования отчета: $e';
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final path = await excelService.exportReport(
        startDate: startDate,
        endDate: endDate,
        revenue: revenue,
        averageCheck: averageCheck,
        maximumCheck: maximumCheck,
        minimumCheck: minimumCheck,
        hourlyLoad: hourlyLoad,
        topDishes: topDishes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сохранено: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

  Widget statCard(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'export_report',
            onPressed: _exportToExcel,
            tooltip: 'Экспорт отчёта в Excel',
            child: const Icon(Icons.table_chart),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'generate_report',
            onPressed: loadReport,
            icon: const Icon(Icons.analytics),
            label: const Text('Сформировать отчет'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Период отчета',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(isStart: true),
                            child: Text('С ${_formatDate(startDate)}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(isStart: false),
                            child: Text('По ${_formatDate(endDate)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: loadReport,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Обновить'),
                    ),
                  ],
                ),
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            statCard('Выручка', '${revenue.toStringAsFixed(2)} ₽', Icons.payments),
            statCard('Средний чек', '${averageCheck.toStringAsFixed(2)} ₽', Icons.receipt),
            statCard('Максимальный чек', '${maximumCheck.toStringAsFixed(2)} ₽', Icons.trending_up),
            statCard('Минимальный чек', '${minimumCheck.toStringAsFixed(2)} ₽', Icons.trending_down),
            const SizedBox(height: 16),
            const Text(
              'Загруженность по часам',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...hourlyLoad.map(
              (row) => Card(
                child: ListTile(
                  title: Text('${parseInt(row['hour']) ?? 0}:00'),
                  subtitle: Text('Заказов: ${parseInt(row['orders_count']) ?? 0}'),
                  trailing: Text('${parseDouble(row['revenue']).toStringAsFixed(2)} ₽'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ТОП блюд',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...topDishes.map(
              (dish) => Card(
                child: ListTile(
                  title: Text(dish['dish_name'].toString()),
                  subtitle: Text(
                    'Продано: ${parseInt(dish['quantity_sold']) ?? 0}',
                  ),
                  trailing: Text(
                    '${parseDouble(dish['revenue']).toStringAsFixed(2)} ₽',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
