import 'package:flutter/material.dart';

import '../../database/db_service.dart';
import '../../models/category.dart';
import '../../models/converters.dart';
import '../../models/dish.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/dish_repository.dart';
import '../../services/excel_export_service.dart';

class DishesScreen extends StatefulWidget {
  const DishesScreen({super.key});

  @override
  State<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends State<DishesScreen> {
  final DishRepository dishRepository = const DishRepository();
  final CategoryRepository categoryRepository = const CategoryRepository();
  final searchController = TextEditingController();
  final excelService = const ExcelExportService();

  List<Dish> dishes = [];
  List<Category> categories = [];
  bool loading = true;

  int _sortIndex = 0;
  bool _sortAsc = true;

  static const _sortOptions = [
    'По имени',
    'По цене',
    'По категории',
    'По ID',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    try {
      categories = await categoryRepository.getAll();
      dishes = await dishRepository.getAll();
      _applySort();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applySort() {
    dishes.sort((a, b) {
      int cmp;
      switch (_sortIndex) {
        case 0:
          cmp = a.name.compareTo(b.name);
          break;
        case 1:
          cmp = a.price.compareTo(b.price);
          break;
        case 2:
          cmp = getCategoryName(a.categoryId).compareTo(getCategoryName(b.categoryId));
          break;
        case 3:
          cmp = (a.id ?? 0).compareTo(b.id ?? 0);
          break;
        default:
          cmp = a.name.compareTo(b.name);
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
        _sortAsc = true;
      }
      _applySort();
    });
  }

  Future<void> search() async {
    final text = searchController.text.trim();
    if (text.isEmpty) {
      await loadData();
      return;
    }

    setState(() => loading = true);
    try {
      dishes = await dishRepository.search(text);
      _applySort();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String getCategoryName(int? id) {
    final match = categories.where((e) => e.id == id).toList();
    return match.isEmpty ? 'Без категории' : match.first.name;
  }

  Future<void> _showDishDetails(Dish dish) async {
    if (dish.id == null) return;

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final recentOrders = await DbService.instance.query(
      'SELECT oi.*, o.order_number, o.order_date, o.total_amount, o.status, w.name as waiter_name '
      'FROM order_items oi '
      'JOIN orders o ON o.id = oi.order_id '
      'LEFT JOIN waiters w ON w.id = o.waiter_id '
      'WHERE oi.dish_id = ? '
      'ORDER BY o.order_date DESC '
      'LIMIT 5',
      arguments: [dish.id],
    );

    final stats = await DbService.instance.queryOne(
      'SELECT COALESCE(SUM(oi.quantity), 0) as total_qty, COALESCE(SUM(oi.line_total), 0) as total_revenue '
      'FROM order_items oi '
      'JOIN orders o ON o.id = oi.order_id '
      'WHERE oi.dish_id = ? AND o.order_date >= ?',
      arguments: [dish.id, thirtyDaysAgo],
    );

    final totalQty = parseInt(stats?['total_qty']) ?? 0;
    final totalRevenue = parseDouble(stats?['total_revenue']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dish.name),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Категория', getCategoryName(dish.categoryId)),
                _infoRow('Цена', '${dish.price.toStringAsFixed(2)} ₽'),
                if (dish.volume != null && dish.volume!.isNotEmpty)
                  _infoRow('Объём', '${dish.volume} ${dish.unit ?? 'шт'}'),
                if (dish.description != null && dish.description!.isNotEmpty)
                  _infoRow('Описание', dish.description!),
                _infoRow('Статус', dish.isActive ? 'Активно' : 'Неактивно'),
                const Divider(height: 20),
                Text(
                  'Статистика за 30 дней',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 6),
                _infoRow('Продано порций', '$totalQty'),
                _infoRow('Выручка', '${totalRevenue.toStringAsFixed(2)} ₽'),
                if (recentOrders.isNotEmpty) ...[
                  const Divider(height: 20),
                  Text(
                    'Последние заказы',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 6),
                  ...recentOrders.map((o) {
                    final orderDate = parseDateTime(o['order_date']);
                    final dateStr = orderDate != null
                        ? '${orderDate.day.toString().padLeft(2, '0')}.${orderDate.month.toString().padLeft(2, '0')}.${orderDate.year}'
                        : '';
                    final waiter = o['waiter_name']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${o['order_number']}  $dateStr',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'x${o['quantity']}  ${parseDouble(o['line_total']).toStringAsFixed(0)} ₽'
                                  '${waiter.isNotEmpty ? '  ($waiter)' : ''}',
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _orderStatusColor(o['status']?.toString() ?? '').withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              o['status']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 10,
                                color: _orderStatusColor(o['status']?.toString() ?? ''),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'Новый':
        return Colors.blue;
      case 'Готовится':
        return Colors.orange;
      case 'Подан':
        return Colors.green;
      case 'Готово':
        return Colors.teal;
      case 'Оплачен':
        return Colors.indigo;
      case 'Отменён':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.end)),
      ],
    ),
  );

  Future<void> _showDishDialog({Dish? dish}) async {
    final nameController = TextEditingController(text: dish?.name ?? '');
    final priceController =
        TextEditingController(text: dish?.price.toString() ?? '');
    final descriptionController =
        TextEditingController(text: dish?.description ?? '');
    int? selectedCategoryId = dish?.categoryId;
    bool active = dish?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(dish == null ? 'Добавить блюдо' : 'Редактирование блюда'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Категория',
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategoryId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Цена'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Описание'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Активно'),
                      value: active,
                      onChanged: (value) {
                        setDialogState(() {
                          active = value;
                        });
                      },
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
      ),
    );

    if (result != true) return;

    final model = Dish(
      id: dish?.id,
      categoryId: selectedCategoryId,
      name: nameController.text.trim(),
      price: double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      isActive: active,
      createdAt: dish?.createdAt,
    );

    if (dish == null) {
      await dishRepository.create(model);
    } else {
      await dishRepository.update(model);
    }

    await loadData();
  }

  Future<void> _deleteDish(Dish dish) async {
    if (dish.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Удалить блюдо "${dish.name}"?'),
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

    if (confirmed != true) return;

    await dishRepository.delete(dish.id!);
    await loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Блюдо удалено')),
    );
  }

  Future<void> _toggleDish(Dish dish) async {
    if (dish.id == null) return;
    await dishRepository.toggleActive(dish.id!, !dish.isActive);
    await loadData();
  }

  Future<void> _exportToExcel() async {
    try {
      final path = await excelService.exportDishes(dishes, getCategoryName);
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
            heroTag: 'export_dishes',
            onPressed: _exportToExcel,
            tooltip: 'Экспорт в Excel',
            child: const Icon(Icons.table_chart),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_dish',
            onPressed: () => _showDishDialog(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Поиск блюда',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => search(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: search,
                  child: const Text('Найти'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadData,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: dishes.length,
                itemBuilder: (_, index) {
                  final dish = dishes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(dish.id?.toString() ?? ''),
                      ),
                      title: Text(dish.name),
                      subtitle: Text(
                        [
                          'Категория: ${getCategoryName(dish.categoryId)}',
                          'Цена: ${dish.price.toStringAsFixed(2)} ₽',
                          if (dish.description != null && dish.description!.trim().isNotEmpty)
                            dish.description!,
                          if (!dish.isActive) 'Неактивно',
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                      onTap: () => _showDishDetails(dish),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            icon: Icon(dish.isActive ? Icons.visibility : Icons.visibility_off),
                            tooltip: dish.isActive ? 'Скрыть' : 'Показать',
                            onPressed: () => _toggleDish(dish),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Редактировать',
                            onPressed: () => _showDishDialog(dish: dish),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Удалить',
                            onPressed: () => _deleteDish(dish),
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
