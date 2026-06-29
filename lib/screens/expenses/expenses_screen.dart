import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../repositories/expense_repository.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseRepository _repository = const ExpenseRepository();
  String _selectedPeriod = 'month';
  String? _selectedCategory;
  List<Expense> _expenses = [];
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _categoryBreakdown = [];
  bool _isLoading = true;

  final List<String> _categories = [
    'Продукты',
    'Зарплата',
    'Коммунальные',
    'Оборудование',
    'Маркетинг',
    'Другое',
  ];

  final Map<String, IconData> _categoryIcons = {
    'Продукты': Icons.restaurant,
    'Зарплата': Icons.people,
    'Коммунальные': Icons.home,
    'Оборудование': Icons.build,
    'Маркетинг': Icons.campaign,
    'Другое': Icons.category,
  };

  final Map<String, Color> _categoryColors = {
    'Продукты': Colors.orange,
    'Зарплата': Colors.blue,
    'Коммунальные': Colors.green,
    'Оборудование': Colors.purple,
    'Маркетинг': Colors.pink,
    'Другое': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final expenses = await _repository.getAll();
      final summary = await _repository.getExpensesSummary();
      final breakdown = await _repository.getCategoryBreakdown();
      final grandTotal = breakdown.fold<double>(0, (sum, item) => sum + ((item['total'] as num?) ?? 0).toDouble());
      final enriched = breakdown.map((item) {
        final total = ((item['total'] as num?) ?? 0).toDouble();
        return {
          ...item,
          'percentage': grandTotal > 0 ? (total / grandTotal) * 100 : 0.0,
        };
      }).toList();
      setState(() {
        _expenses = expenses;
        _summary = summary;
        _categoryBreakdown = enriched;
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

  List<Expense> get _filteredExpenses {
    var filtered = _expenses;
    if (_selectedCategory != null) {
      filtered = filtered.where((e) => e.category == _selectedCategory).toList();
    }
    return filtered;
  }

  String _formatAmount(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} ₽';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _showCreateDialog() {
    String category = _categories.first;
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final supplierController = TextEditingController();
    final receiptController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новый расход'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(_categoryIcons[c], size: 20),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Сумма',
                    border: OutlineInputBorder(),
                    suffixText: '₽',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Дата'),
                  subtitle: Text(_formatDate(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: supplierController,
                  decoration: const InputDecoration(
                    labelText: 'Поставщик (необязательно)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: receiptController,
                  decoration: const InputDecoration(
                    labelText: 'Номер чека (необязательно)',
                    border: OutlineInputBorder(),
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
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите корректную сумму')),
                  );
                  return;
                }
                final expense = Expense(
                  category: category,
                  description: descriptionController.text,
                  amount: amount,
                  expenseDate: selectedDate,
                  supplier: supplierController.text.isNotEmpty ? supplierController.text : null,
                  receiptNumber: receiptController.text.isNotEmpty ? receiptController.text : null,
                );
                await _repository.create(expense);
                if (context.mounted) Navigator.pop(context);
                _loadData();
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Expense expense) {
    String category = expense.category;
    final descriptionController = TextEditingController(text: expense.description);
    final amountController = TextEditingController(text: expense.amount.toString());
    final supplierController = TextEditingController(text: expense.supplier ?? '');
    final receiptController = TextEditingController(text: expense.receiptNumber ?? '');
    DateTime selectedDate = expense.expenseDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Редактировать расход'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(_categoryIcons[c], size: 20),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Сумма',
                    border: OutlineInputBorder(),
                    suffixText: '₽',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Дата'),
                  subtitle: Text(_formatDate(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: supplierController,
                  decoration: const InputDecoration(
                    labelText: 'Поставщик (необязательно)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: receiptController,
                  decoration: const InputDecoration(
                    labelText: 'Номер чека (необязательно)',
                    border: OutlineInputBorder(),
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
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите корректную сумму')),
                  );
                  return;
                }
                final updated = Expense(
                  id: expense.id,
                  category: category,
                  description: descriptionController.text,
                  amount: amount,
                  expenseDate: selectedDate,
                  supplier: supplierController.text.isNotEmpty ? supplierController.text : null,
                  receiptNumber: receiptController.text.isNotEmpty ? receiptController.text : null,
                );
                await _repository.update(updated);
                if (context.mounted) Navigator.pop(context);
                _loadData();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseDetail(Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _categoryColors[expense.category]?.withOpacity(0.2),
                  child: Icon(_categoryIcons[expense.category], color: _categoryColors[expense.category]),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(expense.description, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            _infoRow('Категория', expense.category),
            _infoRow('Сумма', _formatAmount(expense.amount)),
            _infoRow('Дата', _formatDate(expense.expenseDate)),
            if (expense.supplier != null && expense.supplier!.isNotEmpty)
              _infoRow('Поставщик', expense.supplier!),
            if (expense.receiptNumber != null && expense.receiptNumber!.isNotEmpty)
              _infoRow('Чек №', expense.receiptNumber!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.end)),
      ],
    ),
  );

  void _showDeleteConfirmation(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить расход?'),
        content: Text('Вы уверены, что хотите удалить "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await _repository.delete(expense.id!);
              if (context.mounted) Navigator.pop(context);
              _loadData();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расходы'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'today', child: Text('Сегодня')),
              const PopupMenuItem(value: 'week', child: Text('Неделя')),
              const PopupMenuItem(value: 'month', child: Text('Месяц')),
              const PopupMenuItem(value: 'quarter', child: Text('Квартал')),
              const PopupMenuItem(value: 'year', child: Text('Год')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Итого расходов',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(((_summary['total_expenses'] as num?) ?? 0).toDouble()),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categoryBreakdown.map((item) {
                              final cat = item['category'] as String;
                              final total = ((item['total'] as num?) ?? 0).toDouble();
                              return Chip(
                                avatar: Icon(
                                  _categoryIcons[cat],
                                  size: 18,
                                  color: _categoryColors[cat],
                                ),
                                label: Text('${cat}: ${_formatAmount(total)}'),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: const Text('Все'),
                          selected: _selectedCategory == null,
                          onSelected: (_) => setState(() => _selectedCategory = null),
                        ),
                        const SizedBox(width: 8),
                        ..._categories.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(
                              _categoryIcons[cat],
                              size: 18,
                              color: _categoryColors[cat],
                            ),
                            label: Text(cat),
                            selected: _selectedCategory == cat,
                            onSelected: (_) => setState(
                              () => _selectedCategory = _selectedCategory == cat ? null : cat,
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_filteredExpenses.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(
                                'Нет расходов',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._filteredExpenses.map((expense) => Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        onTap: () => _showExpenseDetail(expense),
                        leading: CircleAvatar(
                          backgroundColor: _categoryColors[expense.category]?.withOpacity(0.2),
                          child: Icon(
                            _categoryIcons[expense.category],
                            color: _categoryColors[expense.category],
                          ),
                        ),
                        title: Text(expense.description),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${expense.category} • ${_formatDate(expense.expenseDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (expense.supplier != null)
                              Text(
                                'Поставщик: ${expense.supplier}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (expense.receiptNumber != null)
                              Text(
                                'Чек: ${expense.receiptNumber}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatAmount(expense.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _formatDate(expense.expenseDate),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                                const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.red))),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') _showEditDialog(expense);
                                else if (value == 'delete') _showDeleteConfirmation(expense);
                              },
                            ),
                          ],
                        ),
                      ),
                    )),
                  const SizedBox(height: 8),
                  if (_categoryBreakdown.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Расходы по категориям',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 16),
                            ..._categoryBreakdown.map((item) {
                              final cat = item['category'] as String;
                              final total = ((item['total'] as num?) ?? 0).toDouble();
                              final percentage = ((item['percentage'] as num?) ?? 0).toDouble();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _categoryIcons[cat],
                                              size: 18,
                                              color: _categoryColors[cat],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(cat),
                                          ],
                                        ),
                                        Text(
                                          '${_formatAmount(total)} (${percentage.toStringAsFixed(1)}%)',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      color: _categoryColors[cat],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
