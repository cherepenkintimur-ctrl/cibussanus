import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../repositories/category_repository.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final CategoryRepository repository = const CategoryRepository();
  final searchController = TextEditingController();

  List<Category> categories = [];
  bool loading = true;

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
    } finally {
      if (mounted) setState(() => loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
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
