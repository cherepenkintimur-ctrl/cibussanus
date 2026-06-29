import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../models/cash_register.dart';
import '../../repositories/cash_register_repository.dart';
import '../../widgets/charts.dart';
import '../../widgets/export_dialog.dart';

class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> {
  final CashRegisterRepository _repository = const CashRegisterRepository();
  final TextEditingController _openingBalanceController =
      TextEditingController(text: '0');
  final TextEditingController _openingNotesController =
      TextEditingController();
  final TextEditingController _closingBalanceController =
      TextEditingController();
  final TextEditingController _closingNotesController =
      TextEditingController();

  CashRegister? _openRegister;
  List<CashRegister> _registerHistory = [];
  Map<String, dynamic>? _lastZReport;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _openingBalanceController.dispose();
    _openingNotesController.dispose();
    _closingBalanceController.dispose();
    _closingNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _openRegister = await _repository.getOpen();
      _registerHistory = await _repository.getAll();
      if (_openRegister != null && _openRegister!.id != null) {
        await _repository.updateTotals(_openRegister!.id!);
        _openRegister = await _repository.getOpen();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOpenRegister() async {
    final balance =
        double.tryParse(_openingBalanceController.text) ?? 0;
    final notes = _openingNotesController.text.trim();

    setState(() => _isProcessing = true);
    try {
      await _repository.create(
        CashRegister(
          openTime: DateTime.now(),
          openingBalance: balance,
          notes: notes.isNotEmpty ? notes : null,
        ),
      );
      _openingBalanceController.text = '0';
      _openingNotesController.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Касса успешно открыта')),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка открытия кассы: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _closeRegister() async {
    if (_openRegister == null || _openRegister!.id == null) return;

    final closingBalance =
        double.tryParse(_closingBalanceController.text) ?? 0;
    final notes = _closingNotesController.text.trim();

    setState(() => _isProcessing = true);
    try {
      await _repository.closeRegister(
        _openRegister!.id!,
        closingBalance: closingBalance,
        notes: notes.isNotEmpty ? notes : null,
      );
      _closingBalanceController.clear();
      _closingNotesController.clear();

      final zReport = await _repository.getZReport(_openRegister!.id!);
      setState(() => _lastZReport = zReport);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Касса успешно закрыта')),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка закрытия кассы: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showOpenRegisterDialog() {
    _openingBalanceController.text = '0';
    _openingNotesController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Открыть кассу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _openingBalanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Начальный баланс',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _openingNotesController,
              decoration: const InputDecoration(
                labelText: 'Примечания (необязательно)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: _isProcessing ? null : _handleOpenRegister,
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Открыть'),
          ),
        ],
      ),
    );
  }

  void _showCloseRegisterDialog() {
    if (_openRegister == null) return;
    final expectedBalance = _openRegister!.totalCash;
    _closingBalanceController.text = expectedBalance.toStringAsFixed(2);
    _closingNotesController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final closingBalance =
              double.tryParse(_closingBalanceController.text) ?? 0;
          final discrepancy = closingBalance - expectedBalance;

          return AlertDialog(
            title: const Text('Закрыть кассу / Z-отчёт'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSummaryRow(
                    'Ожидаемая сумма',
                    '${expectedBalance.toStringAsFixed(2)} ₽',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _closingBalanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Конечный баланс (фактически)',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Расхождение',
                    '${discrepancy.toStringAsFixed(2)} ₽',
                    valueColor: discrepancy < 0
                        ? Colors.red
                        : discrepancy > 0
                            ? Colors.green
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _closingNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Примечания (необязательно)',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: _isProcessing ? null : _closeRegister,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Закрыть и сформировать Z-отчёт'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Касса'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_lastZReport != null) ...[
                    _buildZReportCard(theme),
                    const SizedBox(height: 16),
                  ],
                  if (_openRegister != null) ...[
                    _buildActiveRegisterCard(theme),
                  ] else ...[
                    _buildClosedRegisterCard(theme),
                  ],
                  const SizedBox(height: 16),
                  _buildHistorySection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildClosedRegisterCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.point_of_sale,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Нет активной кассы',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Откройте кассу для начала записи продаж',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showOpenRegisterDialog,
              icon: const Icon(Icons.lock_open),
              label: const Text('Открыть кассу'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRegisterCard(ThemeData theme) {
    final totalRevenue = _openRegister!.totalCash +
        _openRegister!.totalCard +
        _openRegister!.totalOther;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'ОТКРЫТА',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                  Text(
                    'Открыта: ${_formatDateTime(_openRegister!.openTime)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (_openRegister!.notes != null &&
                _openRegister!.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _openRegister!.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTotalChip(
                    theme,
                    'Наличные',
                    '${_openRegister!.totalCash.toStringAsFixed(2)} ₽',
                    Icons.money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildTotalChip(
                    theme,
                    'Карта',
                    '${_openRegister!.totalCard.toStringAsFixed(2)} ₽',
                    Icons.credit_card,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildTotalChip(
                    theme,
                    'Прочее',
                    '${_openRegister!.totalOther.toStringAsFixed(2)} ₽',
                    Icons.payment,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildTotalChip(
                    theme,
                    'Итого',
                    '${totalRevenue.toStringAsFixed(2)} ₽',
                    Icons.summarize,
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.receipt_long, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '${_openRegister!.totalOrders} заказов обработано',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (totalRevenue > 0) ...[
              SizedBox(
                height: 160,
                child: PieChartWidget(
                  data: {
                    'Наличные': _openRegister!.totalCash,
                    'Карта': _openRegister!.totalCard,
                    'Прочее': _openRegister!.totalOther,
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Обновить'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _showCloseRegisterDialog,
                    icon: const Icon(Icons.lock, size: 16),
                    label: const Text('Закрыть кассу'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalChip(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZReportCard(ThemeData theme) {
    final report = _lastZReport!;
    final reg = report['register'] as Map<String, dynamic>;
    final hourlyBreakdown = (report['hourly_breakdown'] as List?) ?? [];
    final topDishes = (report['top_dishes'] as List?) ?? [];
    final double regOpeningBalance = (reg['opening_balance'] as num?)?.toDouble() ?? 0;
    final double regClosingBalance = (reg['closing_balance'] as num?)?.toDouble() ?? 0;
    final double regDiscrepancy = (reg['discrepancy'] as num?)?.toDouble() ?? 0;
    final double regTotalCash = (reg['total_cash'] as num?)?.toDouble() ?? 0;
    final double regTotalCard = (reg['total_card'] as num?)?.toDouble() ?? 0;
    final double regTotalOther = (reg['total_other'] as num?)?.toDouble() ?? 0;
    final regNotes = reg['notes']?.toString();
    final closeTime = reg['close_time'] != null ? DateTime.tryParse(reg['close_time'].toString()) : null;
    final totalRevenue = regTotalCash + regTotalCard + regTotalOther;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Z-ОТЧЁТ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    closeTime != null ? _formatDateTime(closeTime) : '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildReportSectionTitle(theme, 'Балансы'),
            const SizedBox(height: 6),
            _buildSummaryRow('Начальный', '${regOpeningBalance.toStringAsFixed(2)} ₽'),
            _buildSummaryRow('Конечный', '${regClosingBalance.toStringAsFixed(2)} ₽'),
            _buildSummaryRow('Выручка', '${totalRevenue.toStringAsFixed(2)} ₽'),
            const Divider(height: 24),
            _buildReportSectionTitle(theme, 'Выручка по способу оплаты'),
            const SizedBox(height: 6),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    Text(
                      'Способ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Сумма',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                _buildTableRow('Наличные', '${regTotalCash.toStringAsFixed(2)} ₽'),
                _buildTableRow('Карта', '${regTotalCard.toStringAsFixed(2)} ₽'),
                _buildTableRow('Прочее', '${regTotalOther.toStringAsFixed(2)} ₽'),
                _buildTableRow(
                  'Итого',
                  '${totalRevenue.toStringAsFixed(2)} ₽',
                  isBold: true,
                ),
              ],
            ),
            const Divider(height: 24),
            _buildReportSectionTitle(theme, 'Почасовая разбивка'),
            const SizedBox(height: 6),
            if (hourlyBreakdown.isEmpty)
              Text(
                'Нет почасовых данных',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              )
            else
              ...hourlyBreakdown.map(
                (entry) {
                  final hour = (entry['hour'] as num?)?.toInt() ?? 0;
                  final total = (entry['total'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          '${total.toStringAsFixed(2)} ₽',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const Divider(height: 24),
            _buildReportSectionTitle(theme, 'Топ-5 блюд'),
            const SizedBox(height: 6),
            if (topDishes.isEmpty)
              Text(
                'Нет данных по блюдам',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              )
            else
              ...topDishes.asMap().entries.map(
                (entry) {
                  final dish = entry.value;
                  final name = dish['name']?.toString() ?? '';
                  final qty = (dish['qty'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            '${entry.key + 1}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          'x$qty',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            if (regDiscrepancy != 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: regDiscrepancy < 0
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: regDiscrepancy < 0
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      regDiscrepancy < 0
                          ? Icons.warning_amber
                          : Icons.check_circle,
                      size: 16,
                      color: regDiscrepancy < 0
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Расхождение: ${regDiscrepancy.toStringAsFixed(2)} ₽',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: regDiscrepancy < 0
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            if (regNotes != null && regNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Примечания',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(regNotes, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportZReport,
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Экспорт'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareZReportCsv,
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _lastZReport = null);
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Закрыть'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSectionTitle(ThemeData theme, String title) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: theme.colorScheme.primary,
      ),
    );
  }

  TableRow _buildTableRow(String label, String value, {bool isBold = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'История касс',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${_registerHistory.length} записей',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_registerHistory.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 36,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Нет истории касс',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._registerHistory.map(
            (register) => _buildHistoryItem(theme, register),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(ThemeData theme, CashRegister register) {
    final isOpen = register.closeTime == null;
    final totalRevenue =
        register.totalCash + register.totalCard + register.totalOther;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isOpen
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isOpen ? Icons.lock_open : Icons.lock,
            size: 16,
            color: isOpen ? Colors.green : Colors.grey[600],
          ),
        ),
        title: Text(
          _formatDateTime(register.openTime),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: isOpen
            ? const Text('Сейчас открыта')
            : Text(
                'Закрыта: ${_formatDateTime(register.closeTime!)}',
                style: theme.textTheme.bodySmall,
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${totalRevenue.toStringAsFixed(2)} ₽',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${register.totalOrders} заказов',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportZReport() async {
    if (_lastZReport == null) return;
    final report = _lastZReport!;
    final reg = report['register'] as Map<String, dynamic>;
    final hourly = (report['hourly_breakdown'] as List?) ?? [];
    final topDishes = (report['top_dishes'] as List?) ?? [];

    await showExportDialog(
      context,
      title: 'Экспорт Z-отчёта',
      actions: [
        ExportAction(
          label: 'Экспорт в CSV',
          icon: Icons.description,
          extension: 'csv',
          generateData: () async {
            final buf = StringBuffer();
            buf.writeln('Z-ОТЧЁТ');
            buf.writeln('Показатель,Значение');
            buf.writeln('Начальный баланс,${reg['opening_balance']}');
            buf.writeln('Конечный баланс,${reg['closing_balance']}');
            buf.writeln('Наличные,${reg['total_cash']}');
            buf.writeln('Карта,${reg['total_card']}');
            buf.writeln('Прочее,${reg['total_other']}');
            buf.writeln('Расхождение,${reg['discrepancy']}');
            buf.writeln();
            if (hourly.isNotEmpty) {
              buf.writeln('Час,Выручка');
              for (final h in hourly) {
                buf.writeln('${h['hour']}:00,${h['total']}');
              }
              buf.writeln();
            }
            if (topDishes.isNotEmpty) {
              buf.writeln('Блюдо,Количество');
              for (final d in topDishes) {
                buf.writeln('${d['name']},${d['qty']}');
              }
            }
            return Uint8List.fromList(buf.toString().codeUnits);
          },
        ),
        ExportAction(
          label: 'Экспорт в TXT',
          icon: Icons.text_snippet,
          extension: 'txt',
          generateData: () async {
            final buf = StringBuffer();
            buf.writeln('========================================');
            buf.writeln('          Z-ОТЧЁТ');
            buf.writeln('========================================');
            buf.writeln('Начальный баланс: ${reg['opening_balance']} ₽');
            buf.writeln('Конечный баланс: ${reg['closing_balance']} ₽');
            buf.writeln('Наличные: ${reg['total_cash']} ₽');
            buf.writeln('Карта: ${reg['total_card']} ₽');
            buf.writeln('Прочее: ${reg['total_other']} ₽');
            buf.writeln('Расхождение: ${reg['discrepancy']} ₽');
            buf.writeln('========================================');
            if (hourly.isNotEmpty) {
              buf.writeln('\nПочасовая разбивка:');
              for (final h in hourly) {
                buf.writeln('  ${h['hour']}:00 — ${h['total']} ₽');
              }
            }
            if (topDishes.isNotEmpty) {
              buf.writeln('\nТоп блюд:');
              for (final d in topDishes) {
                buf.writeln('  ${d['name']} x${d['qty']}');
              }
            }
            return Uint8List.fromList(buf.toString().codeUnits);
          },
        ),
      ],
    );
  }

  Future<void> _shareZReportCsv() async {
    if (_lastZReport == null) return;
    final report = _lastZReport!;
    final reg = report['register'] as Map<String, dynamic>;

    final headers = ['Показатель', 'Значение'];
    final rows = <List<dynamic>>[
      ['Начальный баланс', '${reg['opening_balance']} ₽'],
      ['Конечный баланс', '${reg['closing_balance']} ₽'],
      ['Наличные', '${reg['total_cash']} ₽'],
      ['Карта', '${reg['total_card']} ₽'],
      ['Прочее', '${reg['total_other']} ₽'],
      ['Расхождение', '${reg['discrepancy']} ₽'],
    ];

    await showExportDialog(
      context,
      title: 'Экспорт данных кассы',
      actions: [
        ExportAction(
          label: 'Экспорт в CSV',
          icon: Icons.description,
          extension: 'csv',
          generateData: () async => Uint8List.fromList(generateCsv(headers, rows).codeUnits),
        ),
      ],
    );
  }
}
