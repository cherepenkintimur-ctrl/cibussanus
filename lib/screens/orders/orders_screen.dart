import 'package:flutter/material.dart';

import '../../models/converters.dart';
import '../../models/dish.dart';
import '../../models/order.dart';
import '../../models/order_dish_selection.dart';
import '../../models/order_item.dart';
import '../../models/waiter.dart';
import '../../models/restaurant_table.dart';
import '../../models/discount.dart';
import '../../repositories/dish_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/waiter_repository.dart';
import '../../repositories/table_repository.dart';
import '../../repositories/discount_repository.dart';
import '../../repositories/tip_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../models/tip.dart';
import '../../models/customer.dart';
import '../../services/excel_export_service.dart';
import '../receipt/receipt_view_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderRepository repository = const OrderRepository();
  final DishRepository dishRepository = const DishRepository();
  final WaiterRepository waiterRepository = const WaiterRepository();
  final TableRepository tableRepository = const TableRepository();
  final DiscountRepository discountRepository = const DiscountRepository();
  final excelService = const ExcelExportService();

  List<OrderModel> orders = [];
  List<Waiter> waiters = [];
  List<RestaurantTable> tables = [];
  List<Discount> discounts = [];
  bool loading = true;

  String _statusFilter = 'Все';
  int? _waiterFilter;
  int? _tableFilter;
  String? _paymentFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const _statuses = [
    'Все',
    'Новый',
    'Готовится',
    'Готово',
    'Подан',
    'Оплачен',
    'Отменён',
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'Новый': return Colors.blue;
      case 'Готовится': return Colors.orange;
      case 'Готово': return Colors.green;
      case 'Подан': return Colors.teal;
      case 'Оплачен': return Colors.grey;
      case 'Отменён': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Новый': return Icons.fiber_new;
      case 'Готовится': return Icons.local_fire_department;
      case 'Готово': return Icons.check_circle;
      case 'Подан': return Icons.restaurant;
      case 'Оплачен': return Icons.payment;
      case 'Отменён': return Icons.cancel;
      default: return Icons.receipt;
    }
  }

  @override
  void initState() {
    super.initState();
    loadOrders();
    _loadRelatedData();
  }

  Future<void> _loadRelatedData() async {
    waiters = await waiterRepository.getAll(onlyActive: true);
    tables = await tableRepository.getAll();
    discounts = await discountRepository.getAll();
    if (mounted) setState(() {});
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    return 'CS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> loadOrders() async {
    setState(() { loading = true; });
    orders = await repository.getAll();
    if (!mounted) return;
    setState(() { loading = false; });
  }

  List<OrderModel> get _filteredOrders {
    var result = orders;
    if (_statusFilter != 'Все') {
      result = result.where((o) => o.status == _statusFilter).toList();
    }
    if (_waiterFilter != null) {
      result = result.where((o) => o.waiterId == _waiterFilter).toList();
    }
    if (_tableFilter != null) {
      result = result.where((o) => o.tableId == _tableFilter).toList();
    }
    if (_paymentFilter != null) {
      result = result.where((o) => o.paymentMethod == _paymentFilter).toList();
    }
    if (_dateFrom != null) {
      result = result.where((o) => o.orderDate != null && o.orderDate!.isAfter(_dateFrom!)).toList();
    }
    if (_dateTo != null) {
      final end = _dateTo!.add(const Duration(days: 1));
      result = result.where((o) => o.orderDate != null && o.orderDate!.isBefore(end)).toList();
    }
    return result;
  }

  Future<void> _openOrderForm({OrderModel? order}) async {
    final orderNumberController = TextEditingController(
      text: order?.orderNumber ?? _generateOrderNumber(),
    );
    final notesController = TextEditingController(text: order?.notes ?? '');

    String paymentMethod = order?.paymentMethod ?? 'Наличные';
    int? selectedWaiterId = order?.waiterId;
    int? selectedTableId = order?.tableId;
    int? selectedDiscountId = order?.discountId;
    String selectedStatus = order?.status ?? 'Новый';

    final allDishes = await dishRepository.getAll(onlyActive: true);
    final activeWaiters = await waiterRepository.getAll(onlyActive: true);
    final activeDiscounts = await discountRepository.getActive();

    final selected = <int, OrderDishSelection>{};

    if (order != null && order.id != null) {
      final details = await repository.getDetails(order.id!);
      for (final row in details) {
        final dishId = parseInt(row['dish_id']);
        if (dishId == null) continue;
        Dish? dish;
        try {
          dish = allDishes.firstWhere((d) => d.id == dishId);
        } catch (_) {
          dish = Dish(id: dishId, name: row['dish_name'].toString(), price: parseDouble(row['unit_price']), description: null, isActive: true);
        }
        selected[dishId] = OrderDishSelection(dish: dish, quantity: parseInt(row['quantity']) ?? 1);
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final subtotal = selected.values.fold<double>(0, (sum, item) => sum + item.total);
            double discountAmount = 0;
            if (selectedDiscountId != null) {
              try {
                final disc = activeDiscounts.firstWhere((d) => d.id == selectedDiscountId);
                discountAmount = disc.calculateDiscount(subtotal);
              } catch (_) {}
            }
            final total = subtotal - discountAmount;

            return AlertDialog(
              title: Text(order == null ? 'Новый заказ' : 'Редактирование заказа'),
              content: SizedBox(
                width: 750,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: orderNumberController,
                        decoration: const InputDecoration(labelText: 'Номер заказа', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedWaiterId,
                              decoration: const InputDecoration(labelText: 'Официант', border: OutlineInputBorder()),
                              items: activeWaiters.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                              onChanged: (v) => setDialogState(() => selectedWaiterId = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedTableId,
                              decoration: const InputDecoration(labelText: 'Столик', border: OutlineInputBorder()),
                              items: tables.map((t) => DropdownMenuItem(
                                value: t.id,
                                child: Text('№${t.tableNumber} (${t.capacity} мест, ${t.zone})'),
                              )).toList(),
                              onChanged: (v) => setDialogState(() => selectedTableId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: paymentMethod,
                              decoration: const InputDecoration(labelText: 'Оплата', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'Наличные', child: Text('Наличные')),
                                DropdownMenuItem(value: 'Карта', child: Text('Карта')),
                                DropdownMenuItem(value: 'Смешанная', child: Text('Смешанная')),
                              ],
                              onChanged: (v) { if (v != null) setDialogState(() => paymentMethod = v); },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedDiscountId,
                              decoration: const InputDecoration(labelText: 'Скидка', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Без скидки')),
                                ...activeDiscounts.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text('${d.code} (${d.type == "percent" ? "${d.value}%" : "${d.value}₽"})'),
                                )),
                              ],
                              onChanged: (v) => setDialogState(() => selectedDiscountId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(labelText: 'Статус', border: OutlineInputBorder()),
                        items: _statuses.where((s) => s != 'Все').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) { if (v != null) setDialogState(() => selectedStatus = v); },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: 'Комментарий', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Блюда', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 8),
                      ...allDishes.map((dish) {
                        final selection = selected[dish.id!];
                        final checked = selection != null;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: CheckboxListTile(
                              value: checked,
                              title: Text(dish.name),
                              subtitle: Text('${dish.price.toStringAsFixed(0)} ₽'),
                              secondary: checked
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: () {
                                            if (selection != null && selection.quantity > 1) {
                                              setDialogState(() => selection.quantity--);
                                            }
                                          },
                                        ),
                                        SizedBox(
                                          width: 24,
                                          child: Text(
                                            selection!.quantity.toString(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: () {
                                            if (selection != null) {
                                              setDialogState(() => selection.quantity++);
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  : null,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selected[dish.id!] = OrderDishSelection(dish: dish);
                                  } else {
                                    selected.remove(dish.id);
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Подытог:'),
                                Text('${subtotal.toStringAsFixed(2)} ₽'),
                              ],
                            ),
                            if (discountAmount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Скидка:', style: TextStyle(color: Colors.green)),
                                  Text('-${discountAmount.toStringAsFixed(2)} ₽', style: const TextStyle(color: Colors.green)),
                                ],
                              ),
                            ],
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('ИТОГО:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text(
                                  '${total.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    if (selected.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно блюдо')),
      );
      return;
    }

    final subtotal = selected.values.fold<double>(0, (sum, item) => sum + item.total);
    double discountAmt = 0;
    if (selectedDiscountId != null) {
      try {
        final disc = activeDiscounts.firstWhere((d) => d.id == selectedDiscountId);
        discountAmt = disc.calculateDiscount(subtotal);
      } catch (_) {}
    }

    final items = selected.values
        .map((e) => OrderItem(
              orderId: order?.id ?? 0,
              dishId: e.dish.id!,
              quantity: e.quantity,
              unitPrice: e.dish.price,
              lineTotal: e.total,
            ))
        .toList();

    if (order == null) {
      await repository.create(
        orderNumber: orderNumberController.text.trim(),
        paymentMethod: paymentMethod,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        waiterId: selectedWaiterId,
        tableId: selectedTableId,
        discountId: selectedDiscountId,
        discountAmount: discountAmt,
        status: selectedStatus,
        items: items,
      );
    } else {
      await repository.updateWithItems(
        id: order.id!,
        orderNumber: orderNumberController.text.trim(),
        paymentMethod: paymentMethod,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        waiterId: selectedWaiterId,
        tableId: selectedTableId,
        discountId: selectedDiscountId,
        discountAmount: discountAmt,
        status: selectedStatus,
        items: items,
      );
    }

    await loadOrders();
  }

  Future<void> deleteOrder(OrderModel order) async {
    if (order.id == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление заказа'),
        content: Text('Удалить заказ ${order.orderNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да')),
        ],
      ),
    );
    if (result == true) {
      await repository.delete(order.id!);
      await loadOrders();
    }
  }

  Future<void> showDetails(OrderModel order) async {
    if (order.id == null) return;
    final details = await repository.getDetails(order.id!);
    final tips = await TipRepository().getAll();
    final orderTips = tips.where((t) => t.orderId == order.id).toList();

    Customer? customer;
    if (order.customerId != null) {
      try {
        customer = await CustomerRepository().getById(order.customerId!);
      } catch (_) {}
    }

    final waiter = waiters.where((w) => w.id == order.waiterId).firstOrNull;
    final table = tables.where((t) => t.id == order.tableId).firstOrNull;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Заказ ${order.orderNumber}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _detailRow('Дата', order.orderDate?.toString().substring(0, 16) ?? ''),
                _detailRow('Статус', order.status),
                _detailRow('Оплата', order.paymentMethod ?? ''),
                if (order.discountAmount > 0)
                  _detailRow('Скидка', '-${order.discountAmount.toStringAsFixed(2)} ₽'),
                _detailRow('Сумма', '${order.totalAmount.toStringAsFixed(2)} ₽'),
                if (order.notes != null && order.notes!.isNotEmpty)
                  _detailRow('Комментарий', order.notes!),

                if (waiter != null) ...[
                  const SizedBox(height: 12),
                  Text('Официант', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 6),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow('Имя', waiter.name),
                          _detailRow('Роль', waiter.role),
                          if (waiter.phone != null && waiter.phone!.isNotEmpty)
                            _detailRow('Телефон', waiter.phone!),
                        ],
                      ),
                    ),
                  ),
                ],

                if (table != null) ...[
                  const SizedBox(height: 12),
                  Text('Столик', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 6),
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow('Номер', '№${table.tableNumber}'),
                          _detailRow('Зона', table.zone),
                          _detailRow('Вместимость', '${table.capacity} мест'),
                        ],
                      ),
                    ),
                  ),
                ],

                if (customer != null) ...[
                  const SizedBox(height: 12),
                  Text('Клиент', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 6),
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow('Имя', customer.name),
                          if (customer.phone != null && customer.phone!.isNotEmpty)
                            _detailRow('Телефон', customer.phone!),
                          if (customer.email != null && customer.email!.isNotEmpty)
                            _detailRow('Эл. почта', customer.email!),
                          _detailRow('Визитов', '${customer.visitCount}'),
                          _detailRow('Лояльность', customer.loyaltyTier),
                        ],
                      ),
                    ),
                  ),
                ],

                if (orderTips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Чаевые', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 6),
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final tip in orderTips)
                            _detailRow('Чаевые', '${tip.amount.toStringAsFixed(0)} ₽'),
                          const Divider(),
                          _detailRow(
                            'Итого чаевых',
                            '${orderTips.fold<double>(0, (sum, t) => sum + t.amount).toStringAsFixed(0)} ₽',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(),
                const Text('Состав:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...details.map((item) {
                  return ListTile(
                    dense: true,
                    title: Text(item['dish_name'].toString()),
                    subtitle: Text('x${parseInt(item['quantity']) ?? 0}'),
                    trailing: Text('${parseDouble(item['line_total']).toStringAsFixed(2)} ₽'),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptViewScreen(order: order),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Чек'),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      final allDetails = await repository.getAllDetailsBatch();
      final path = await excelService.exportOrders(orders, (orderId) {
        return allDetails[orderId] ?? [];
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Сохранено: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }

    final filtered = _filteredOrders;

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'export_orders',
            onPressed: _exportToExcel,
            tooltip: 'Экспорт в Excel',
            child: const Icon(Icons.table_chart),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_order',
            onPressed: _openOrderForm,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _statuses.length,
              itemBuilder: (_, index) {
                final status = _statuses[index];
                final isSelected = _statusFilter == status;
                final count = status == 'Все' ? orders.length : orders.where((o) => o.status == status).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('$status ($count)', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                      selected: isSelected,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      onSelected: (_) => setState(() => _statusFilter = status),
                      avatar: status != 'Все' ? Icon(_statusIcon(status), size: 16, color: isSelected ? Colors.white : _statusColor(status)) : null,
                    ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text('Найдено: ${filtered.length}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('Итого: ${_sum(filtered).toStringAsFixed(0)} ₽', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadOrders,
              color: Theme.of(context).colorScheme.primary,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filtered.length,
                itemBuilder: (_, index) {
                  final order = filtered[index];
                  final statusColor = _statusColor(order.status);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      onTap: () => showDetails(order),
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        child: Icon(_statusIcon(order.status), color: statusColor, size: 20),
                      ),
                      title: Row(
                        children: [
                          Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(order.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${order.orderDate?.toString().substring(0, 16) ?? ''} • ${order.paymentMethod ?? ''}',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          if (order.waiterId != null || order.tableId != null)
                            Text(
                              [
                                if (order.waiterId != null)
                                  waiters.where((w) => w.id == order.waiterId).map((w) => w.name).firstOrNull ?? '',
                                if (order.tableId != null)
                                  'Столик №${tables.where((t) => t.id == order.tableId).map((t) => t.tableNumber).firstOrNull ?? ''}',
                              ].join(' • '),
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusAction(order),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${order.finalAmount.toStringAsFixed(0)} ₽',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                              ),
                              if (order.discountAmount > 0)
                                Text(
                                  '-${order.discountAmount.toStringAsFixed(0)} ₽',
                                  style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 10),
                                ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _openOrderForm(order: order);
                              } else if (value == 'delete') {
                                await deleteOrder(order);
                              } else if (value == 'receipt') {
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReceiptViewScreen(order: order),
                                  ),
                                );
                              } else if (value.startsWith('status:')) {
                                final newStatus = value.substring(7);
                                await repository.updateStatus(order.id!, newStatus);
                                await loadOrders();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                              const PopupMenuItem(value: 'receipt', child: Text('Просмотр чека')),
                              if (order.status != 'Оплачен' && order.status != 'Отменён')
                                ...['Новый', 'Готовится', 'Готово', 'Подан', 'Оплачен'].map(
                                  (s) => PopupMenuItem(
                                    value: 'status:$s',
                                    child: Row(
                                      children: [
                                        Icon(_statusIcon(s), size: 16, color: _statusColor(s)),
                                        const SizedBox(width: 8),
                                        Text(s),
                                      ],
                                    ),
                                  ),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Color(0xFFC62828)))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAction(OrderModel order) {
    switch (order.status) {
      case 'Готово':
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            icon: Icon(Icons.restaurant, color: Theme.of(context).colorScheme.tertiary, size: 20),
            tooltip: 'Подать',
            onPressed: () async {
              await repository.updateStatus(order.id!, 'Подан');
              await loadOrders();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Заказ подан')),
              );
            },
          ),
        );
      case 'Подан':
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            icon: Icon(Icons.payment, color: Theme.of(context).colorScheme.primary, size: 20),
            tooltip: 'Оплатить',
            onPressed: () async {
              await repository.updateStatus(order.id!, 'Оплачен');
              await loadOrders();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Заказ оплачен. Стол свободен.')),
              );
            },
          ),
        );
      case 'Новый':
      case 'Готовится':
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: 'Готовится на кухне',
            child: Icon(
              Icons.local_fire_department,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  double _sum(List<OrderModel> list) => list.fold(0, (s, o) => s + o.finalAmount);

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Официант', _waiterFilter != null ? waiters.where((w) => w.id == _waiterFilter).map((w) => w.name).firstOrNull ?? '' : 'Все', () => _showWaiterFilter()),
            const SizedBox(width: 8),
            _filterChip('Столик', _tableFilter != null ? '№$_tableFilter' : 'Все', () => _showTableFilter()),
            const SizedBox(width: 8),
            _filterChip('Оплата', _paymentFilter ?? 'Все', () => _showPaymentFilter()),
            const SizedBox(width: 8),
            _filterChip('Дата', _dateFrom != null ? '${_formatShort(_dateFrom!)}–${_formatShort(_dateTo ?? DateTime.now())}' : 'Все', () => _showDateFilter()),
            if (_waiterFilter != null || _tableFilter != null || _paymentFilter != null || _dateFrom != null) ...[
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('Сбросить', style: TextStyle(fontSize: 11, color: Color(0xFFC62828))),
                onPressed: () => setState(() {
                  _waiterFilter = null;
                  _tableFilter = null;
                  _paymentFilter = null;
                  _dateFrom = null;
                  _dateTo = null;
                }),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, VoidCallback onTap) {
    final isActive = value != 'Все';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isActive ? const Color(0xFFF5E6D0) : Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFFF5E6D0) : Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  void _showWaiterFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Официант', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(title: const Text('Все'), onTap: () { setState(() => _waiterFilter = null); Navigator.pop(context); }),
                    ...waiters.map((w) => ListTile(
                      title: Text(w.name),
                      trailing: _waiterFilter == w.id ? const Icon(Icons.check, color: Color(0xFF6B1520)) : null,
                      onTap: () { setState(() => _waiterFilter = w.id); Navigator.pop(context); },
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTableFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Столик', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(title: const Text('Все'), onTap: () { setState(() => _tableFilter = null); Navigator.pop(context); }),
                    ...tables.map((t) => ListTile(
                      title: Text('№${t.tableNumber} (${t.zone})'),
                      trailing: _tableFilter == t.id ? const Icon(Icons.check, color: Color(0xFF6B1520)) : null,
                      onTap: () { setState(() => _tableFilter = t.id); Navigator.pop(context); },
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentFilter() {
    final methods = ['Наличные', 'Карта', 'Смешанная'];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Способ оплаты', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ListTile(title: const Text('Все'), onTap: () { setState(() => _paymentFilter = null); Navigator.pop(context); }),
            ...methods.map((m) => ListTile(
              title: Text(m),
              trailing: _paymentFilter == m ? const Icon(Icons.check, color: Color(0xFF6B1520)) : null,
              onTap: () { setState(() => _paymentFilter = m); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }

  void _showDateFilter() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (from == null) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: from,
      lastDate: DateTime.now(),
    );
    setState(() {
      _dateFrom = from;
      _dateTo = to ?? DateTime.now();
    });
  }

  String _formatShort(DateTime d) => '${d.day}.${d.month}';
}
