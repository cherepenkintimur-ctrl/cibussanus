import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../repositories/category_repository.dart';
import '../../services/excel_export_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final CategoryRepository repository = const CategoryRepository();
  final searchController = TextEditingController();
  final excelService = const ExcelExportService();

  List<Category> categories = [];
  bool loading = true;

  int _sortIndex = 0;
  bool _sortAsc = true;

  static const _sortOptions = [
    'По имени',
    'По ID',
    'По дате',
  ];

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadCategories() async {
    setState(() => loading = true);
    try {
      categories = await repository.getAll();
      _applySort();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applySort() {
    categories.sort((a, b) {
      int cmp;
      switch (_sortIndex) {
        case 0:
          cmp = a.name.compareTo(b.name);
          break;
        case 1:
          cmp = (a.id ?? 0).compareTo(b.id ?? 0);
          break;
        case 2:
          cmp = (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0));
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
      await loadCategories();
      return;
    }

    setState(() => loading = true);
    try {
      categories = await repository.search(text);
      _applySort();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showCategoryDialog({Category? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController =
        TextEditingController(text: category?.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(category == null ? 'Добавить категорию' : 'Редактирование категории'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                ),
              ),
            ],
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
      ),
    );

    if (result != true) return;

    final model = Category(
      id: category?.id,
      name: nameController.text.trim(),
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      createdAt: category?.createdAt,
    );

    if (category == null) {
      await repository.create(model);
    } else {
      await repository.update(model);
    }

    await loadCategories();
  }

  Future<void> _deleteCategory(Category category) async {
    if (category.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Удалить категорию "${category.name}"?'),
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

    await repository.delete(category.id!);
    await loadCategories();
  }

  Future<void> _exportToExcel() async {
    try {
      final path = await excelService.exportCategories(categories);
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
            heroTag: 'export_categories',
            onPressed: _exportToExcel,
            tooltip: 'Экспорт в Excel',
            child: const Icon(Icons.table_chart),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_category',
            onPressed: () => _showCategoryDialog(),
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
                      hintText: 'Поиск категории',
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
              onRefresh: loadCategories,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: categories.length,
                itemBuilder: (_, index) {
                  final category = categories[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(category.id?.toString() ?? ''),
                      ),
                      title: Text(category.name),
                      subtitle: Text(category.description ?? 'Описание отсутствует'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Редактировать',
                            onPressed: () => _showCategoryDialog(category: category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Удалить',
                            onPressed: () => _deleteCategory(category),
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
