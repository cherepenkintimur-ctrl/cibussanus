import 'package:flutter/material.dart';

import '../../models/category.dart';
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
                      initialValue: selectedCategoryId,
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
