import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/converters.dart';
import '../../repositories/order_repository.dart';
import '../receipt/receipt_view_screen.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen>
    with SingleTickerProviderStateMixin {
  final OrderRepository _repository = const OrderRepository();

  List<OrderModel> _orders = [];
  final Map<int, List<Map<String, dynamic>>> _orderItems = {};
  bool _loading = true;
  Timer? _timer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadOrders();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadOrders());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final orders = await _repository.getKitchenOrders();
    final items = <int, List<Map<String, dynamic>>>{};
    for (final order in orders) {
      if (order.id != null) {
        items[order.id!] = await _repository.getOrderItemsForKitchen(order.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _orderItems.clear();
      _orderItems.addAll(items);
      _loading = false;
    });
  }

  String _formatElapsed(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inHours > 0) {
      return '${diff.inHours}ч ${diff.inMinutes % 60}мин';
    }
    return '${diff.inMinutes}мин';
  }

  Color _elapsedColor(DateTime? date) {
    if (date == null) return Colors.grey;
    final minutes = DateTime.now().difference(date).inMinutes;
    if (minutes < 15) return Colors.green;
    if (minutes < 30) return Colors.orange;
    return Colors.red;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Новый':
        return Colors.blue;
      case 'Готовится':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  bool _isUrgent(DateTime? date) {
    if (date == null) return false;
    return DateTime.now().difference(date).inMinutes > 20;
  }

  void _showOrderDetail(OrderModel order) {
    final items = _orderItems[order.id] ?? [];
    final elapsed = _formatElapsed(order.orderDate);
    final statusCol = _statusColor(order.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: statusCol,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Заказ #${order.orderNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _detailRow(Icons.timer_outlined, 'Время в работе', elapsed),
                    if (order.orderDate != null)
                      _detailRow(
                        Icons.access_time,
                        'Дата и время',
                        '${order.orderDate!.day.toString().padLeft(2, '0')}.${order.orderDate!.month.toString().padLeft(2, '0')}.${order.orderDate!.year}  '
                        '${order.orderDate!.hour.toString().padLeft(2, '0')}:${order.orderDate!.minute.toString().padLeft(2, '0')}',
                      ),
                    if (order.tableId != null)
                      _detailRow(Icons.table_restaurant, 'Стол', '${order.tableId}'),
                    if (order.waiterId != null)
                      _detailRow(Icons.person_outline, 'Официант', '#${order.waiterId}'),
                    const Divider(height: 28),
                    const Text(
                      'Состав заказа',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Нет блюд', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...items.map((item) {
                        final qty = parseInt(item['quantity']) ?? 0;
                        final name = item['dish_name']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: statusCol,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 28),
                    _detailRow(Icons.payments_outlined, 'Итого', '${order.finalAmount.toStringAsFixed(2)} ₽'),
                    if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty)
                      _detailRow(Icons.credit_card_outlined, 'Оплата', order.paymentMethod!),
                    if (order.discountAmount > 0)
                      _detailRow(Icons.local_offer_outlined, 'Скидка', '-${order.discountAmount.toStringAsFixed(2)} ₽'),
                    if (order.notes != null && order.notes!.isNotEmpty)
                      _detailRow(Icons.notes_outlined, 'Заметки', order.notes!),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptViewScreen(order: order)));
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('ЧЕК', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('ЗАКРЫТЬ', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(OrderModel order, String newStatus) async {
    await _repository.updateStatus(order.id!, newStatus);
    await _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'КУХНЯ',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            tooltip: 'Обновить',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _orders.isEmpty
          ? const Center(
              child: Text(
                'Нет активных заказов',
                style: TextStyle(fontSize: 22, color: Colors.grey),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount =
                    (constraints.maxWidth / 420).floor().clamp(1, 5);
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) =>
                      _buildOrderCard(_orders[index]),
                );
              },
            ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final items = _orderItems[order.id] ?? [];
    final urgent = _isUrgent(order.orderDate);
    final elapsed = _formatElapsed(order.orderDate);
    final elapsedCol = _elapsedColor(order.orderDate);
    final statusCol = _statusColor(order.status);

    Widget card = Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusCol, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusCol.withValues(alpha: 0.12),
              statusCol.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showOrderDetail(order),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '#${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: elapsedCol,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  elapsed,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusCol,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (order.tableId != null || order.waiterId != null) ...[
                        const SizedBox(height: 8),
                        if (order.tableId != null)
                          Row(
                            children: [
                              Icon(Icons.table_restaurant,
                                  size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                'Стол ${order.tableId}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        if (order.waiterId != null)
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                'Официант #${order.waiterId}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(
                                child: Text(
                                  'Нет блюд',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final qty = parseInt(item['quantity']) ?? 0;
                                  final name = item['dish_name']?.toString() ?? '';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: statusCol,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$qty',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusButtons(order),
            ],
          ),
        ),
      ),
    );

    if (urgent) {
      card = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildStatusButtons(OrderModel order) {
    switch (order.status) {
      case 'Новый':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus(order, 'Готовится'),
            icon: const Icon(Icons.play_arrow, size: 22),
            label: const Text(
              'В РАБОТУ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      case 'Готовится':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus(order, 'Готово'),
            icon: const Icon(Icons.check_circle, size: 22),
            label: const Text(
              'ГОТОВО',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
