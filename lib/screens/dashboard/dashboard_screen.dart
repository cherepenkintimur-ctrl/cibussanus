import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../repositories/report_repository.dart';
import '../../repositories/order_repository.dart';
import '../../models/order.dart';
import '../../models/converters.dart';
import '../receipt/receipt_view_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReportRepository _reportRepo = const ReportRepository();
  final OrderRepository _orderRepo = const OrderRepository();

  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<OrderModel> _recentOrders = [];
  List<Map<String, dynamic>> _revenueTrend = [];
  double _yesterdayRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final stats = await _reportRepo.todayStats();
      final allOrders = await _orderRepo.getAll();
      final recent = allOrders.take(5).toList();

      final trend = await _reportRepo.dailyRevenueTrend(
        startDate: DateTime.now().subtract(const Duration(days: 14)),
      );

      final now = DateTime.now();
      final yesterdayStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      final yesterdayEnd = DateTime(now.year, now.month, now.day);
      final yesterdayRevenue = await _reportRepo.revenueByPeriod(
        startDate: yesterdayStart,
        endDate: yesterdayEnd,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _recentOrders = recent;
          _revenueTrend = trend;
          _yesterdayRevenue = yesterdayRevenue;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatCurrency(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k ₽';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Доброе утро';
    if (hour < 17) return 'Добрый день';
    return 'Добрый вечер';
  }

  String _formatDate() {
    final now = DateTime.now();
    final months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final weekdays = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return '${weekdays[now.weekday]}, ${now.day} ${months[now.month]} ${now.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Новый':
        return Colors.blue;
      case 'Готовится':
        return Colors.orange;
      case 'Подан':
        return Colors.teal;
      case 'Оплачен':
        return Colors.green;
      case 'Отменен':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHeaderCard() {
    final revenue = parseDouble(_stats['revenue']);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D1A1E), Color(0xFF5B1020), Color(0xFF7A1A28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3D1A1E).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A96E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Color(0xFFC9A96E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: const TextStyle(
                          color: Color(0xFFC9A96E),
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        'CibusSanus',
                        style: TextStyle(
                          color: Color(0xFFF5E6D0),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(),
              style: TextStyle(
                color: const Color(0xFFC9A96E).withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Выручка сегодня',
              style: TextStyle(
                color: const Color(0xFFC9A96E).withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${revenue.toStringAsFixed(0)} ₽',
              style: const TextStyle(
                color: Color(0xFFF5E6D0),
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueTrendCard() {
    if (_revenueTrend.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    final labels = <String>[];
    double maxY = 0;

    for (int i = 0; i < _revenueTrend.length; i++) {
      final rev = parseDouble(_revenueTrend[i]['revenue']);
      spots.add(FlSpot(i.toDouble(), rev));
      final dateStr = _revenueTrend[i]['date']?.toString() ?? '';
      labels.add(dateStr.length >= 10 ? dateStr.substring(5, 10) : '$i');
      if (rev > maxY) maxY = rev;
    }

    final todayRevenue = parseDouble(_stats['revenue']);
    final diff = _yesterdayRevenue > 0 ? ((todayRevenue - _yesterdayRevenue) / _yesterdayRevenue * 100) : 0;
    final isUp = diff >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
                const SizedBox(width: 6),
                Text('Выручка за 14 дней', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUp ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isUp ? Icons.trending_up : Icons.trending_down, size: 14, color: isUp ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                      const SizedBox(width: 4),
                      Text(
                        '${isUp ? '+' : ''}${diff.toStringAsFixed(1)}% к вчера',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isUp ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 0 ? maxY / 3 : 1, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFE0E0E0), strokeWidth: 0.5)),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: (_revenueTrend.length / 5).ceilToDouble().clamp(1.0, double.infinity),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Text(labels[idx], style: const TextStyle(fontSize: 9, color: Colors.grey));
                        }
                        return const SizedBox.shrink();
                      },
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: _revenueTrend.length > 2,
                       color: Theme.of(context).colorScheme.primary,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: _revenueTrend.length <= 14, getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 2.5, color: Theme.of(context).colorScheme.primary, strokeColor: Colors.white, strokeWidth: 1.5)),
                      belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool compact = false,
    VoidCallback? onTap,
  }) {
    final card = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }

  Widget _buildStatsGrid() {
    final items = [
      _StatItem(
        label: 'Заказов сегодня',
        value: '${_stats['order_count'] ?? 0}',
        icon: Icons.shopping_cart_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      _StatItem(
        label: 'Выручка',
        value: _formatCurrency(parseDouble(_stats['revenue'])),
        icon: Icons.payments_outlined,
        color: const Color(0xFF2E7D32),
      ),
      _StatItem(
        label: 'Средний чек',
        value: _formatCurrency(parseDouble(_stats['avg_check'])),
        icon: Icons.receipt_long_outlined,
        color: Theme.of(context).colorScheme.secondary,
      ),
      _StatItem(
        label: 'Активных заказов',
        value: '${_stats['active_orders'] ?? 0}',
        icon: Icons.pending_actions_outlined,
        color: const Color(0xFFE65100),
      ),
      _StatItem(
        label: 'Чаевые сегодня',
        value: _formatCurrency(parseDouble(_stats['tips_today'])),
        icon: Icons.volunteer_activism_outlined,
        color: const Color(0xFFC62828),
      ),
      _StatItem(
        label: 'Столиков свободно',
        value: '${_stats['tables_free'] ?? 0}/${_stats['tables_total'] ?? 0}',
        icon: Icons.table_restaurant_outlined,
        color: const Color(0xFF4A148C),
      ),
      _StatItem(
        label: 'На смене',
        value: '${_stats['active_shifts'] ?? 0}',
        icon: Icons.people_outline,
        color: const Color(0xFF1565C0),
      ),
      _StatItem(
        label: 'Бронирований',
        value: '${_stats['reservations_today'] ?? 0}',
        icon: Icons.event_outlined,
        color: Color(0xFFC9A96E),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.35,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildStatCard(
          label: item.label,
          value: item.value,
          icon: item.icon,
          color: item.color,
          onTap: () => _showStatExplanation(item.label),
        );
      },
    );
  }

  Widget _buildTopDishCard() {
    final topDish = _stats['top_dish'] ?? '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.secondary, Color(0xFFA0714A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6D0).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.star_outline,
                color: Color(0xFFF5E6D0),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Популярное блюдо дня',
                    style: TextStyle(
                      color: const Color(0xFFF5E6D0).withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topDish,
                    style: const TextStyle(
                      color: Color(0xFFF5E6D0),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetail(OrderModel order) {
    final amount = order.totalAmount;
    final date = order.orderDate;
    final status = order.status;
    final orderNumber = order.orderNumber;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.access_time, 'Время', _formatTime(date)),
            const SizedBox(height: 10),
            _detailRow(Icons.payments_outlined, 'Сумма', '${amount.toStringAsFixed(0)} ₽'),
            const SizedBox(height: 16),
            _buildDashboardStatusAction(order),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptViewScreen(order: order)));
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Чек'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/orders');
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('К заказам'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardStatusAction(OrderModel order) {
    switch (order.status) {
      case 'Готово':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await _orderRepo.updateStatus(order.id!, 'Подан');
              if (!mounted) return;
              Navigator.pop(context);
              _loadDashboard();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Заказ подан')),
              );
            },
            icon: const Icon(Icons.restaurant, size: 18),
            label: const Text('Подать', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      case 'Подан':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await _orderRepo.updateStatus(order.id!, 'Оплачен');
              if (!mounted) return;
              Navigator.pop(context);
              _loadDashboard();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Заказ оплачен. Стол свободен.')),
              );
            },
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Оплатить', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      case 'Новый':
      case 'Готовится':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Готовится на кухне',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }

  void _showStatExplanation(String label) {
    final descriptions = {
      'Заказов сегодня': 'Общее количество заказов, созданных за сегодняшний день.',
      'Выручка': 'Суммарная выручка за сегодня — все оплаченные заказы.',
      'Средний чек': 'Средняя сумма одного заказа за сегодня.',
      'Активных заказов': 'Количество заказов, которые сейчас в процессе выполнения.',
      'Чаевые сегодня': 'Сумма всех чаевых, оставленных клиентами сегодня.',
      'Столиков свободно': 'Количество свободных столиков из общего числа.',
      'На смене': 'Количество сотрудников, сейчас работающих на смене.',
      'Бронирований': 'Количество бронирований на сегодня.',
    };

    final description = descriptions[label] ?? 'Нет описания.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(description, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Закрыть', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Последние заказы',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Заказов пока нет',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ...List.generate(_recentOrders.length, (index) {
                final order = _recentOrders[index];
                final amount = order.totalAmount;
                final date = order.orderDate;
                final status = order.status;

                return GestureDetector(
                  onTap: () => _showOrderDetail(order),
                  child: Container(
                    margin: EdgeInsets.only(
                      bottom: index < _recentOrders.length - 1 ? 10 : 0,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderNumber,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatTime(date)} • $status',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${amount.toStringAsFixed(0)} ₽',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Загрузка...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Панель управления',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 8),
              _buildRevenueTrendCard(),
              const SizedBox(height: 8),
              _buildStatsGrid(),
              const SizedBox(height: 8),
              _buildTopDishCard(),
              const SizedBox(height: 8),
              _buildRecentOrdersCard(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
