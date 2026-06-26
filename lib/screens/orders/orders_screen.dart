import 'package:flutter/material.dart';

import '../../models/converters.dart';
import '../../models/dish.dart';
import '../../models/order.dart';
import '../../models/order_dish_selection.dart';
import '../../models/order_item.dart';
import '../../repositories/dish_repository.dart';
import '../../repositories/order_repository.dart';
import '../../services/excel_export_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderRepository repository = const OrderRepository();
  final DishRepository dishRepository = const DishRepository();
  final excelService = const ExcelExportService();

  List<OrderModel> orders = [];
  bool loading = true;

  int _sortIndex = 0;
  bool _sortAsc = false;

  static const _sortOptions = [
    'По дате',
    'По сумме',
    'По номеру',
    'По оплате',
  ];

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    return 'CS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> loadOrders() async {
    setState(() {
      loading = true;
    });

    orders = await repository.getAll();
    _applySort();

    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  void _applySort() {
    orders.sort((a, b) {
      int cmp;
      switch (_sortIndex) {
        case 0:
          cmp = (a.orderDate ?? DateTime(0)).compareTo(b.orderDate ?? DateTime(0));
          break;
        case 1:
          cmp = a.totalAmount.compareTo(b.totalAmount);
          break;
        case 2:
          cmp = a.orderNumber.compareTo(b.orderNumber);
          break;
        case 3:
          cmp = (a.paymentMethod ?? '').compareTo(b.paymentMethod ?? '');
          break;
        default:
          cmp = (a.orderDate ?? DateTime(0)).compareTo(b.orderDate ?? DateTime(0));
      }
      return _sortAsc ? cmp : -cmp;
    });
  }

  void _toggleSort(int index) {
    setState(() {
      if (_sortIndex == index) {
        _sortAsc = !_sortAsc;
      } else {
        _sortIndex = index;
        _sortAsc = index == 0 ? false : true;
      }
      _applySort();
    });
  }

  Future<void> createOrder() async {
    await _openOrderForm();
  }

  Future<void> editOrder(OrderModel order) async {
    await _openOrderForm(order: order);
  }

  Future<void> _openOrderForm({OrderModel? order}) async {
    final orderNumberController = TextEditingController(
      text: order?.orderNumber ?? _generateOrderNumber(),
    );
    final notesController = TextEditingController(text: order?.notes ?? '');

    String paymentMethod = order?.paymentMethod ?? 'Наличные';

    final allDishes = await dishRepository.getAll(onlyActive: true);

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
          dish = Dish(
            id: dishId,
            name: row['dish_name'].toString(),
            price: parseDouble(row['unit_price']),
            description: null,
            isActive: true,
          );
        }

        selected[dishId] = OrderDishSelection(
          dish: dish,
          quantity: parseInt(row['quantity']) ?? 1,
        );
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final total = selected.values.fold<double>(
              0,
              (sum, item) => sum + item.total,
            );

            return AlertDialog(
              title: Text(order == null ? 'Создание заказа' : 'Редактирование заказа'),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: orderNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Номер заказа',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Способ оплаты',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Наличные',
                            child: Text('Наличные'),
                          ),
                          DropdownMenuItem(
                            value: 'Карта',
                            child: Text('Карта'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            paymentMethod = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Блюда',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...allDishes.map((dish) {
                        final selection = selected[dish.id!];
                        final checked = selection != null;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: CheckboxListTile(
                              value: checked,
                              title: Text(dish.name),
                              subtitle: Text('${dish.price.toStringAsFixed(2)} ₽'),
                              secondary: checked
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: () {
                                            if (selection != null && selection.quantity > 1) {
                                              setDialogState(() {
                                                selection.quantity--;
                                              });
                                            }
                                          },
                                        ),
                                        SizedBox(
                                          width: 30,
                                          child: Text(
                                            selection?.quantity.toString() ?? '0',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () {
                                            if (selection != null) {
                                              setDialogState(() {
                                                selection.quantity++;
                                              });
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
                      const SizedBox(height: 12),
                      Text(
                        'Итого: ${total.toStringAsFixed(2)} ₽',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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

    final items = selected.values
        .map(
          (e) => OrderItem(
            orderId: order?.id ?? 0,
            dishId: e.dish.id!,
            quantity: e.quantity,
            unitPrice: e.dish.price,
            lineTotal: e.total,
          ),
        )
        .toList();

    if (order == null) {
      await repository.create(
        orderNumber: orderNumberController.text.trim(),
        paymentMethod: paymentMethod,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        items: items,
      );
    } else {
      await repository.updateWithItems(
        id: order.id!,
        orderNumber: orderNumberController.text.trim(),
        paymentMethod: paymentMethod,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да'),
          ),
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

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Заказ ${order.orderNumber}'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Дата: ${order.orderDate?.toString() ?? ''}'),
              Text('Оплата: ${order.paymentMethod ?? ''}'),
              Text('Сумма: ${order.totalAmount.toStringAsFixed(2)} ₽'),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: details.length,
                  itemBuilder: (_, index) {
                    final item = details[index];
                    return ListTile(
                      title: Text(item['dish_name'].toString()),
                      subtitle: Text('Количество: ${parseInt(item['quantity']) ?? 0}'),
                      trailing: Text('${parseDouble(item['line_total']).toStringAsFixed(2)} ₽'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      final detailsCache = <int, List<Map<String, dynamic>>>{};
      for (final o in orders) {
        if (o.id != null) {
          detailsCache[o.id!] = await repository.getDetails(o.id!);
        }
      }
      final path = await excelService.exportOrders(orders, (orderId) {
        return detailsCache[orderId] ?? [];
      });
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
            heroTag: 'export_orders',
            onPressed: _exportToExcel,
            tooltip: 'Экспорт в Excel',
            child: const Icon(Icons.table_chart),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_order',
            onPressed: createOrder,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _sortOptions.length,
              itemBuilder: (_, index) {
                final selected = _sortIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_sortOptions[index]),
                        if (selected) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    selected: selected,
                    onSelected: (_) => _toggleSort(index),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadOrders,
              child: ListView.builder(
                itemCount: orders.length,
                itemBuilder: (_, index) {
                  final order = orders[index];

                  return Card(
                    child: ListTile(
                      onTap: () => showDetails(order),
                      leading: CircleAvatar(
                        child: Text(order.id?.toString() ?? ''),
                      ),
                      title: Text(order.orderNumber),
                      subtitle: Text(
                        '${order.orderDate?.toString() ?? ''}\n${order.paymentMethod ?? ''}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${order.totalAmount.toStringAsFixed(2)} ₽',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Редактировать',
                            onPressed: () => editOrder(order),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Удалить',
                            onPressed: () => deleteOrder(order),
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
}
