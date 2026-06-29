import 'package:flutter/material.dart';
import '../../models/tip.dart';
import '../../models/waiter.dart';
import '../../models/order.dart';
import '../../repositories/tip_repository.dart';
import '../../repositories/waiter_repository.dart';
import '../../repositories/order_repository.dart';
import '../receipt/receipt_view_screen.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  final TipRepository _tipRepo = const TipRepository();
  final WaiterRepository _waiterRepo = const WaiterRepository();
  final OrderRepository _orderRepo = const OrderRepository();

  List<Tip> _tips = [];
  List<Waiter> _waiters = [];
  List<OrderModel> _orders = [];
  Map<String, dynamic> _waiterReport = {};
  List<Map<String, dynamic>> _dailyTrend = [];
  String _selectedPeriod = 'month';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startDate = _getStartDate(now);

      final results = await Future.wait([
        _tipRepo.getAll(),
        _waiterRepo.getAll(),
        _orderRepo.getAll(),
        _tipRepo.getTipsByWaiterReport(startDate: startDate),
        _tipRepo.getTotalTipsAll(startDate: startDate),
        _tipRepo.getDailyTipsTrend(startDate: startDate),
      ]);

      final rawReport = results[3] as List<Map<String, dynamic>>;
      final reportMap = <String, dynamic>{};
      for (final row in rawReport) {
        final id = row['id']?.toString() ?? '';
        reportMap[id] = {
          'waiterName': row['name'] as String? ?? '',
          'tipCount': row['tips_count'] ?? 0,
          'totalTips': row['total_tips'] ?? 0,
          'avgTip': row['avg_tip'] ?? 0,
          'maxTip': row['max_tip'] ?? 0,
        };
      }

      final rawTrend = results[5] as List<Map<String, dynamic>>;
      final trend = rawTrend.map((e) {
        return {
          'date': e['date'] as String? ?? '',
          'total': e['total_tips'] ?? 0,
          'tipsCount': e['tips_count'] ?? 0,
          'avgTip': e['avg_tip'] ?? 0,
        };
      }).toList();

      setState(() {
        _tips = results[0] as List<Tip>;
        _waiters = results[1] as List<Waiter>;
        _orders = results[2] as List<OrderModel>;
        _waiterReport = reportMap;
        _dailyTrend = trend;
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

  DateTime _getStartDate(DateTime now) {
    switch (_selectedPeriod) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  double get _totalTips {
    final report = _waiterReport;
    if (report.isEmpty) return 0;
    double total = 0;
    for (final entry in report.values) {
      final data = entry as Map<String, dynamic>;
      total += (data['totalTips'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  double get _averageTip {
    final report = _waiterReport;
    if (report.isEmpty) return 0;
    int count = 0;
    double total = 0;
    for (final entry in report.values) {
      final data = entry as Map<String, dynamic>;
      total += (data['totalTips'] as num?)?.toDouble() ?? 0;
      count += (data['tipCount'] as int?) ?? 0;
    }
    return count > 0 ? total / count : 0;
  }

  int get _tipsCount {
    final report = _waiterReport;
    if (report.isEmpty) return 0;
    int count = 0;
    for (final entry in report.values) {
      final data = entry as Map<String, dynamic>;
      count += (data['tipCount'] as int?) ?? 0;
    }
    return count;
  }

  String get _topTipper {
    final entry = _getTopTipperEntry();
    if (entry == null) return '—';
    final data = entry.value as Map<String, dynamic>;
    return data['waiterName'] as String? ?? '—';
  }

  MapEntry<String, dynamic>? _getTopTipperEntry() {
    final report = _waiterReport;
    if (report.isEmpty) return null;
    MapEntry<String, dynamic>? topEntry;
    double maxTips = 0;
    for (final entry in report.entries) {
      final data = entry.value as Map<String, dynamic>;
      final tips = (data['totalTips'] as num?)?.toDouble() ?? 0;
      if (tips > maxTips) {
        maxTips = tips;
        topEntry = entry;
      }
    }
    return topEntry;
  }

  void _showAddTipDialog() async {
    final activeWaiters =
        _waiters.where((w) => w.isActive).toList();
    final recentOrders =
        _orders.length > 20 ? _orders.sublist(_orders.length - 20) : _orders;

    OrderModel? selectedOrder;
    Waiter? selectedWaiter;
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить чаевые'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<OrderModel>(
                    decoration: const InputDecoration(
                      labelText: 'Заказ',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedOrder,
                    items: recentOrders.map((order) {
                      return DropdownMenuItem(
                        value: order,
                        child: Text(
                          '№${order.orderNumber} — ${order.totalAmount.toStringAsFixed(0)}₽',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedOrder = val),
                    validator: (val) =>
                        val == null ? 'Выберите заказ' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Waiter>(
                    decoration: const InputDecoration(
                      labelText: 'Официант',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedWaiter,
                    items: activeWaiters.map((waiter) {
                      return DropdownMenuItem(
                        value: waiter,
                        child: Text(waiter.name),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedWaiter = val),
                    validator: (val) =>
                        val == null ? 'Выберите официанта' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Сумма (₽)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Введите сумму';
                      }
                      final num = double.tryParse(val);
                      if (num == null || num <= 0) {
                        return 'Введите положительное число';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop({
                    'orderId': selectedOrder!.id,
                    'waiterId': selectedWaiter!.id,
                    'amount': double.parse(amountController.text),
                  });
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final tip = Tip(
          orderId: result['orderId'] as int?,
          waiterId: result['waiterId'] as int?,
          amount: result['amount'] as double,
          createdAt: DateTime.now(),
        );
        await _tipRepo.create(tip);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Чаевые добавлены')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} ₽';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} $hour:$minute';
  }

  String _getWaiterName(int? waiterId) {
    if (waiterId == null) return '—';
    try {
      final waiter = _waiters.firstWhere((w) => w.id == waiterId);
      return waiter.name;
    } catch (_) {
      return '—';
    }
  }

  String _getOrderNumber(int? orderId) {
    if (orderId == null) return '—';
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      return order.orderNumber;
    } catch (_) {
      return '—';
    }
  }

  void _showTipDetail(Tip tip) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: Text(
                  _formatCurrency(tip.amount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow(context, 'Официант', _getWaiterName(tip.waiterId), colorScheme),
              const SizedBox(height: 12),
              _buildDetailRow(context, 'Заказ', '№${_getOrderNumber(tip.orderId)}', colorScheme),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                'Дата и время',
                tip.createdAt != null ? _formatDate(tip.createdAt!) : '—',
                colorScheme,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final order = _orders.where((o) => o.id == tip.orderId).firstOrNull;
                    if (order != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptViewScreen(order: order)));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Заказ не найден')),
                      );
                    }
                  },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Просмотр чека'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showWaiterDetail(String waiterName, Map<String, dynamic> data) {
    final totalTips = (data['totalTips'] as num?)?.toDouble() ?? 0;
    final avgTip = (data['avgTip'] as num?)?.toDouble() ?? 0;
    final tipCount = (data['tipCount'] as int?) ?? 0;
    final maxTip = (data['maxTip'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: Text(
                  waiterName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow(context, 'Всего чаевых', _formatCurrency(totalTips), colorScheme),
              const SizedBox(height: 12),
              _buildDetailRow(context, 'Количество чаевых', tipCount.toString(), colorScheme),
              const SizedBox(height: 12),
              _buildDetailRow(context, 'Среднее чаевые', _formatCurrency(avgTip), colorScheme),
              const SizedBox(height: 12),
              _buildDetailRow(context, 'Максимум', _formatCurrency(maxTip), colorScheme),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amberScheme = ColorScheme.fromSeed(
      seedColor: Colors.amber,
      brightness: Theme.of(context).brightness,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: amberScheme,
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: amberScheme.primaryContainer,
          foregroundColor: amberScheme.onPrimaryContainer,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Чаевые'),
          actions: [
            _buildPeriodSelector(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddTipDialog,
          icon: const Icon(Icons.add),
          label: const Text('Добавить'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    _buildSummarySection(amberScheme),
                    const SizedBox(height: 8),
                    _buildLeaderboardSection(amberScheme),
                    const SizedBox(height: 8),
                    _buildDailyTrendSection(amberScheme),
                    const SizedBox(height: 8),
                    _buildTipsListSection(amberScheme),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      tooltip: 'Период',
      onSelected: (period) {
        setState(() => _selectedPeriod = period);
        _loadData();
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(value: 'today', child: Text('Сегодня')),
          const PopupMenuItem(value: 'week', child: Text('Неделя')),
          const PopupMenuItem(value: 'month', child: Text('Месяц')),
        ];
      },
    );
  }

  Widget _buildSummarySection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сводка',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          children: [
            _buildSummaryCard(
              icon: Icons.account_balance_wallet,
              title: 'Всего',
              value: _formatCurrency(_totalTips),
              colorScheme: colorScheme,
            ),
            _buildSummaryCard(
              icon: Icons.trending_up,
              title: 'Среднее',
              value: _formatCurrency(_averageTip),
              colorScheme: colorScheme,
            ),
            _buildSummaryCard(
              icon: Icons.receipt_long,
              title: 'Количество',
              value: _tipsCount.toString(),
              colorScheme: colorScheme,
            ),
            _buildSummaryCard(
              icon: Icons.star,
              title: 'Топ',
              value: _topTipper,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardSection(ColorScheme colorScheme) {
    final reportEntries = _waiterReport.entries.toList()
      ..sort((a, b) {
        final aData = a.value as Map<String, dynamic>;
        final bData = b.value as Map<String, dynamic>;
        final aTips =
            (aData['totalTips'] as num?)?.toDouble() ?? 0;
        final bTips =
            (bData['totalTips'] as num?)?.toDouble() ?? 0;
        return bTips.compareTo(aTips);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Топ официантов по чаевым',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        if (reportEntries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Нет данных за выбранный период',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          ...reportEntries.asMap().entries.map((indexedEntry) {
            final rank = indexedEntry.key + 1;
            final entry = indexedEntry.value;
            final data = entry.value as Map<String, dynamic>;
            final totalTips =
                (data['totalTips'] as num?)?.toDouble() ?? 0;
            final avgTip =
                (data['avgTip'] as num?)?.toDouble() ?? 0;
            final tipCount = (data['tipCount'] as int?) ?? 0;
            final maxTip =
                (data['maxTip'] as num?)?.toDouble() ?? 0;
            final waiterName =
                data['waiterName'] as String? ?? entry.key;

            return _buildLeaderboardCard(
              rank: rank,
              waiterName: waiterName,
              totalTips: totalTips,
              avgTip: avgTip,
              tipCount: tipCount,
              maxTip: maxTip,
              colorScheme: colorScheme,
              onTap: () => _showWaiterDetail(waiterName, data),
            );
          }),
      ],
    );
  }

  Widget _buildLeaderboardCard({
    required int rank,
    required String waiterName,
    required double totalTips,
    required double avgTip,
    required int tipCount,
    required double maxTip,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
  }) {
    final isTop = rank == 1;
    return Card(
      elevation: isTop ? 2 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: isTop
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isTop
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: isTop
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                     fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiterName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tipCount чаевых · среднее ${_formatCurrency(avgTip)} · макс. ${_formatCurrency(maxTip)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(totalTips),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTrendSection(ColorScheme colorScheme) {
    if (_dailyTrend.isEmpty) return const SizedBox.shrink();

    final maxVal = _dailyTrend
        .map((e) => (e['total'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Динамика',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _dailyTrend.map((day) {
                  final total = (day['total'] as num?)?.toDouble() ?? 0;
                  final fraction = maxVal > 0 ? total / maxVal : 0.0;
                  final label = (day['date'] as String?) ?? '';
                  final displayLabel =
                      label.length >= 5 ? label.substring(5) : label;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(total),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 8,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: (fraction * 80).clamp(4.0, 80.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.tertiary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            displayLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 9,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsListSection(ColorScheme colorScheme) {
    final sortedTips = List<Tip>.from(_tips)
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'История',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        if (sortedTips.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Нет чаевых за выбранный период',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          ...sortedTips.map((tip) => _buildTipCard(tip, colorScheme)),
      ],
    );
  }

  Widget _buildTipCard(Tip tip, ColorScheme colorScheme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: () => _showTipDetail(tip),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.monetization_on,
            color: colorScheme.primary,
          ),
        ),
        title: Text(
          _formatCurrency(tip.amount),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _getWaiterName(tip.waiterId),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Заказ №${_getOrderNumber(tip.orderId)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        trailing: Text(
          tip.createdAt != null ? _formatDate(tip.createdAt!) : '',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
