import 'package:flutter/material.dart';
import '../../models/inventory_item.dart';
import '../../repositories/inventory_repository.dart';
import '../../widgets/charts.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryRepository _repository = const InventoryRepository();
  final TextEditingController _searchController = TextEditingController();

  List<InventoryItem> _items = [];
  List<InventoryItem> _lowStockItems = [];
  List<String> _categories = [];
  String _selectedCategory = 'Все';
  String _searchQuery = '';
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  static const List<String> _defaultCategories = [
    'Мясо',
    'Рыба',
    'Овощи',
    'Молочные',
    'Бакалея',
    'Напитки',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repository.getAll();
      final lowStock = await _repository.getLowStock();
      final categories = await _repository.getCategories();
      final stats = await _repository.getInventoryStats();

      if (mounted) {
        setState(() {
          _items = items;
          _lowStockItems = lowStock;
          _categories = categories.isEmpty ? _defaultCategories : categories;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  List<InventoryItem> get _filteredItems {
    List<InventoryItem> result = List.from(_items);

    if (_selectedCategory != 'Все') {
      result = result
          .where((item) => item.category == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where(
            (item) =>
                item.name.toLowerCase().contains(query) ||
                item.category.toLowerCase().contains(query) ||
                (item.supplier?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    return result;
  }

  Color _stockLevelColor(double ratio) {
    if (ratio > 0.6) return Colors.green;
    if (ratio >= 0.3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Склад'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
            tooltip: 'Добавить товар',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildStatsSummary(theme)),
                  SliverToBoxAdapter(
                    child: _buildLowStockSection(theme),
                  ),
                  SliverToBoxAdapter(child: _buildChartSection(theme)),
                  SliverToBoxAdapter(child: _buildCategoryFilter(theme)),
                  SliverToBoxAdapter(child: _buildSearchBar(theme)),
                  _filteredItems.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text('Нет товаров'),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildItemCard(
                              _filteredItems[index],
                              theme,
                            ),
                            childCount: _filteredItems.length,
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsSummary(ThemeData theme) {
    if (_stats == null) return const SizedBox.shrink();

    final totalItems = (_stats!['total_items'] ?? 0) as int;
    final totalValue = (_stats!['total_value'] ?? 0.0) as double;
    final lowStockCount = (_stats!['low_stock_count'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.inventory_2,
              label: 'Всего',
              value: '$totalItems',
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.payments,
              label: 'Стоимость',
              value: _formatCurrency(totalValue),
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.warning,
              label: 'Мало',
              value: '$lowStockCount',
              color: lowStockCount > 0 ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockSection(ThemeData theme) {
    if (_lowStockItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Низкий остаток',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_lowStockItems.length} товаров',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._lowStockItems.map(
            (item) => Card(
              color: theme.colorScheme.errorContainer.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.error),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.errorContainer,
                  child: Icon(Icons.warning, color: theme.colorScheme.onErrorContainer),
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Остаток: ${item.currentStock} / мин: ${item.minStock}',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => _showRestockDialog(item),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                  child: const Text('Пополнить'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChartSection(ThemeData theme) {
    final Map<String, double> categoryValues = {};
    for (final item in _items) {
      final value = item.currentStock * item.costPerUnit;
      categoryValues[item.category] =
          (categoryValues[item.category] ?? 0) + value;
    }

    if (categoryValues.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Стоимость по категориям',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 280,
                child: PieChartWidget(
                  data: categoryValues,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(ThemeData theme) {
    final allCategories = ['Все', ..._categories];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = allCategories[index];
          final isSelected = _selectedCategory == cat;

          return FilterChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _selectedCategory = cat);
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Поиск товаров...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item, ThemeData theme) {
    final stockRatio = item.maxStock > 0
        ? (item.currentStock / item.maxStock).clamp(0.0, 1.0)
        : 0.0;
    final isLowStock = item.currentStock <= item.minStock;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isLowStock
              ? BorderSide(color: theme.colorScheme.error, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEditDialog(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isLowStock)
                      Icon(Icons.warning, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) => _handleMenuAction(value, item),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Редактировать'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'restock',
                          child: ListTile(
                            leading: Icon(Icons.add),
                            title: Text('Пополнить'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'deduct',
                          child: ListTile(
                            leading: Icon(Icons.remove),
                            title: Text('Списать'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading:
                                Icon(Icons.delete, color: Colors.red),
                            title: Text('Удалить',
                                style: TextStyle(color: Colors.red)),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        item.category,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Поставщик: ${item.supplier ?? '—'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Остаток: ',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                '${item.currentStock} / ${item.maxStock}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _stockLevelColor(stockRatio),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: stockRatio,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              color: _stockLevelColor(stockRatio),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Мин/Макс',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${item.minStock} / ${item.maxStock}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Цена: ${_formatCurrency(item.costPerUnit)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Стоимость: ${_formatCurrency(item.currentStock * item.costPerUnit)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (item.lastRestocked != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Последнее пополнение: ${_formatDate(item.lastRestocked!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, InventoryItem item) {
    switch (action) {
      case 'edit':
        _showEditDialog(item);
        break;
      case 'restock':
        _showRestockDialog(item);
        break;
      case 'deduct':
        _showDeductDialog(item);
        break;
      case 'delete':
        _showDeleteConfirmation(item);
        break;
    }
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController(text: 'Мясо');
    final stockController = TextEditingController(text: '0');
    final minStockController = TextEditingController(text: '10');
    final maxStockController = TextEditingController(text: '100');
    final costController = TextEditingController();
    final supplierController = TextEditingController();
    final unitController = TextEditingController(text: 'кг');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый товар'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Куриная грудка',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: categoryController.text,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    categoryController.text = value;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Категория',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(
                  labelText: 'Текущий остаток',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minStockController,
                decoration: const InputDecoration(
                  labelText: 'Минимальный остаток',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxStockController,
                decoration: const InputDecoration(
                  labelText: 'Максимальный остаток',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: costController,
                decoration: const InputDecoration(
                  labelText: 'Цена за единицу (₽)',
                  prefixText: '₽ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Ед. измерения',
                  hintText: 'кг, л, шт',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: supplierController,
                decoration: const InputDecoration(
                  labelText: 'Поставщик',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              if (costController.text.isEmpty) return;

              final item = InventoryItem(
                id: DateTime.now().millisecondsSinceEpoch,
                name: nameController.text.trim(),
                category: categoryController.text,
                currentStock:
                    double.tryParse(stockController.text) ?? 0,
                minStock:
                    double.tryParse(minStockController.text) ?? 10,
                maxStock:
                    double.tryParse(maxStockController.text) ?? 100,
                costPerUnit:
                    double.tryParse(costController.text) ?? 0,
                unit: unitController.text.trim().isEmpty
                    ? 'кг'
                    : unitController.text.trim(),
                supplier: supplierController.text.trim().isEmpty
                    ? null
                    : supplierController.text.trim(),
                lastRestocked: DateTime.now(),
              );

              await _repository.create(item);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(InventoryItem item) {
    final nameController = TextEditingController(text: item.name);
    final categoryController =
        TextEditingController(text: item.category);
    final stockController =
        TextEditingController(text: item.currentStock.toString());
    final minStockController =
        TextEditingController(text: item.minStock.toString());
    final maxStockController =
        TextEditingController(text: item.maxStock.toString());
    final costController =
        TextEditingController(text: item.costPerUnit.toString());
    final supplierController =
        TextEditingController(text: item.supplier ?? '');
    final unitController =
        TextEditingController(text: item.unit);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать товар'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: categoryController.text,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    categoryController.text = value;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Категория',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(
                  labelText: 'Текущий остаток',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minStockController,
                decoration: const InputDecoration(
                  labelText: 'Минимальный остаток',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxStockController,
                decoration: const InputDecoration(
                  labelText: 'Максимальный остаток',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: costController,
                decoration: const InputDecoration(
                  labelText: 'Цена за единицу (₽)',
                  prefixText: '₽ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Ед. измерения',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: supplierController,
                decoration: const InputDecoration(
                  labelText: 'Поставщик',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              if (costController.text.isEmpty) return;

              final updated = item.copyWith(
                name: nameController.text.trim(),
                category: categoryController.text,
                currentStock:
                    double.tryParse(stockController.text) ??
                        item.currentStock,
                minStock:
                    double.tryParse(minStockController.text) ??
                        item.minStock,
                maxStock:
                    double.tryParse(maxStockController.text) ??
                        item.maxStock,
                costPerUnit:
                    double.tryParse(costController.text) ??
                        item.costPerUnit,
                unit: unitController.text.trim().isEmpty
                    ? item.unit
                    : unitController.text.trim(),
                supplier: supplierController.text.trim().isEmpty
                    ? null
                    : supplierController.text.trim(),
              );

              await _repository.update(updated);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(InventoryItem item) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Пополнить: ${item.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Текущий остаток: ${item.currentStock} ${item.unit}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Количество для пополнения',
                  prefixText: '+',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите количество';
                  }
                  final num = double.tryParse(value);
                  if (num == null || num <= 0) {
                    return 'Введите положительное число';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final quantity = double.parse(controller.text);
              await _repository.restock(item.id!, quantity);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${item.name} пополнен на $quantity ${item.unit}',
                    ),
                  ),
                );
                _loadData();
              }
            },
            child: const Text('Пополнить'),
          ),
        ],
      ),
    );
  }

  void _showDeductDialog(InventoryItem item) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Списать: ${item.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Текущий остаток: ${item.currentStock} ${item.unit}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Количество для списания',
                  prefixText: '-',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите количество';
                  }
                  final num = double.tryParse(value);
                  if (num == null || num <= 0) {
                    return 'Введите положительное число';
                  }
                  if (num > item.currentStock) {
                    return 'Недостаточно на складе (${item.currentStock})';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final quantity = double.parse(controller.text);
              await _repository.deductStock(item.id!, quantity);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${item.name} списан: $quantity ${item.unit}',
                    ),
                  ),
                );
                _loadData();
              }
            },
            child: const Text('Списать'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text(
          'Вы уверены, что хотите удалить "${item.name}"? '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              await _repository.delete(item.id!);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.name} удалён'),
                  ),
                );
                _loadData();
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k ₽';
    }
    return '${value.toStringAsFixed(0)} ₽';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
