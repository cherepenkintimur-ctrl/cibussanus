import 'package:flutter/material.dart';
import '../../models/discount.dart';
import '../../repositories/discount_repository.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  final DiscountRepository _repository = const DiscountRepository();
  List<Discount> _discounts = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final discounts = await _repository.getAll();
      final stats = await _repository.getDiscountStats();
      setState(() {
        _discounts = discounts;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  bool _isValidNow(Discount d) {
    final now = DateTime.now();
    return now.isAfter(d.validFrom) && now.isBefore(d.validTo);
  }

  bool _isExpired(Discount d) {
    return DateTime.now().isAfter(d.validTo);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatAmount(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} ₽';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Скидки и акции'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildStatsSummary()),
                  SliverToBoxAdapter(child: _buildDiscountStatsSection()),
                  _buildDiscountsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsSummary() {
    final totalDiscountGiven = (_stats['total_discount_given'] as num?)?.toDouble() ?? 0;
    final byDiscount = (_stats['by_discount'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Общая статистика',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.local_offer,
                      'Всего скидок',
                      _discounts.length.toString(),
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      Icons.savings,
                      'Сэкономлено клиентам',
                      _formatAmount(totalDiscountGiven),
                      Theme.of(context).colorScheme.tertiaryContainer,
                      Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.check_circle,
                      'Активных',
                      _discounts.where((d) => d.isActive).length.toString(),
                      Theme.of(context).colorScheme.secondaryContainer,
                      Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      Icons.cancel,
                      'Неактивных',
                      _discounts.where((d) => !d.isActive).length.toString(),
                      Theme.of(context).colorScheme.errorContainer,
                      Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color bgColor, Color fgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: fgColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fgColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountStatsSection() {
    final byDiscount = (_stats['by_discount'] as List?) ?? [];
    if (byDiscount.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Статистика по скидкам',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...byDiscount.map((item) {
                final code = item['code'] as String? ?? '';
                final description = item['description'] as String? ?? '';
                final type = item['type'] as String? ?? 'percent';
                final value = (item['value'] as num?)?.toDouble() ?? 0;
                final usageCount = item['usage_count'] as int? ?? 0;
                final totalAmount = (item['total_discount_amount'] as num?)?.toDouble() ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  code,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (description.isNotEmpty)
                                  Text(
                                    description,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$usageCount использований',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _formatAmount(totalAmount),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountsList() {
    if (_discounts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Нет скидок',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Добавьте первую скидку',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final discount = _discounts[index];
            return _buildDiscountCard(discount);
          },
          childCount: _discounts.length,
        ),
      ),
    );
  }

  Widget _buildDiscountCard(Discount discount) {
    final valid = _isValidNow(discount);
    final expired = _isExpired(discount);
    final borderColor = valid
        ? Colors.green
        : expired
            ? Colors.red
            : Theme.of(context).colorScheme.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDiscountDetail(discount),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          discount.code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (discount.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            discount.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(value, discount),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Редактировать'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(discount.isActive ? Icons.pause : Icons.play_arrow),
                            const SizedBox(width: 8),
                            Text(discount.isActive ? 'Деактивировать' : 'Активировать'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Удалить', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    discount.type == 'percent' ? Icons.percent : Icons.money,
                    discount.type == 'percent'
                        ? '${discount.value.toStringAsFixed(0)}%'
                        : '${discount.value.toStringAsFixed(0)} ₽',
                    Theme.of(context).colorScheme.primaryContainer,
                    fgColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  if (discount.minOrderAmount != null)
                    _buildInfoChip(
                      Icons.shopping_cart,
                      'Мин. ${_formatAmount(discount.minOrderAmount!)}',
                      Theme.of(context).colorScheme.secondaryContainer,
                      fgColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  if (discount.maxDiscountAmount != null)
                    _buildInfoChip(
                      Icons.money_off,
                      'Макс. ${_formatAmount(discount.maxDiscountAmount!)}',
                      Theme.of(context).colorScheme.tertiaryContainer,
                      fgColor: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  _buildInfoChip(
                    Icons.calendar_today,
                    '${_formatDate(discount.validFrom)} - ${_formatDate(discount.validTo)}',
                    valid
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : expired
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                    fgColor: valid
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : expired
                            ? Theme.of(context).colorScheme.onErrorContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  _buildInfoChip(
                    Icons.bar_chart,
                    discount.usageLimit != null
                        ? '${discount.usageCount}/${discount.usageLimit}'
                        : '${discount.usageCount} использований',
                    Theme.of(context).colorScheme.tertiaryContainer,
                    fgColor: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: discount.isActive,
                    onChanged: (_) => _toggleActive(discount),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    discount.isActive ? 'Активна' : 'Неактивна',
                    style: TextStyle(
                      color: discount.isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color bgColor, {Color? fgColor}) {
    final fg = fgColor ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, Discount discount) {
    switch (action) {
      case 'edit':
        _showEditDialog(discount);
        break;
      case 'toggle':
        _toggleActive(discount);
        break;
      case 'delete':
        _showDeleteConfirmation(discount);
        break;
    }
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<Discount>(
      context: context,
      builder: (context) => const _DiscountFormDialog(),
    );
    if (result != null) {
      try {
        await _repository.create(result);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка создания: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(Discount discount) async {
    final result = await showDialog<Discount>(
      context: context,
      builder: (context) => _DiscountFormDialog(discount: discount),
    );
    if (result != null) {
      try {
        await _repository.update(result);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка обновления: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(Discount discount) async {
    try {
      await _repository.toggleActive(discount.id!);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(Discount discount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить скидку?'),
        content: Text('Вы уверены, что хотите удалить скидку "${discount.code}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.delete(discount.id!);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e')),
          );
        }
      }
    }
  }

  void _showDiscountDetail(Discount discount) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DiscountDetailSheet(discount: discount),
    );
  }
}

class _DiscountFormDialog extends StatefulWidget {
  final Discount? discount;

  const _DiscountFormDialog({this.discount});

  @override
  State<_DiscountFormDialog> createState() => _DiscountFormDialogState();
}

class _DiscountFormDialogState extends State<_DiscountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _descriptionController;
  late TextEditingController _valueController;
  late TextEditingController _minOrderController;
  late TextEditingController _maxDiscountController;
  late TextEditingController _usageLimitController;
  late String _selectedType;
  late DateTime _validFrom;
  late DateTime _validTo;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.discount?.code ?? '');
    _descriptionController = TextEditingController(text: widget.discount?.description ?? '');
    _valueController = TextEditingController(
      text: widget.discount?.value.toString() ?? '',
    );
    _minOrderController = TextEditingController(
      text: widget.discount?.minOrderAmount?.toString() ?? '',
    );
    _maxDiscountController = TextEditingController(
      text: widget.discount?.maxDiscountAmount?.toString() ?? '',
    );
    _usageLimitController = TextEditingController(
      text: widget.discount?.usageLimit?.toString() ?? '',
    );
    _selectedType = widget.discount?.type ?? 'percent';
    _validFrom = widget.discount?.validFrom ?? DateTime.now();
    _validTo = widget.discount?.validTo ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _usageLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.discount != null ? 'Редактировать скидку' : 'Новая скидка',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Код скидки',
                            prefixIcon: Icon(Icons.local_offer),
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите код скидки';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Описание',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Тип скидки',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'percent',
                              child: Row(
                                children: [
                                  Icon(Icons.percent, size: 20),
                                  SizedBox(width: 8),
                                  Text('Процент (%)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'fixed',
                              child: Row(
                                children: [
                                  Icon(Icons.money, size: 20),
                                  SizedBox(width: 8),
                                  Text('Фиксированная (₽)'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedType = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _valueController,
                          decoration: InputDecoration(
                            labelText: 'Значение',
                            prefixIcon: const Icon(Icons.numbers),
                            border: const OutlineInputBorder(),
                            suffixText: _selectedType == 'percent' ? '%' : '₽',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите значение';
                            }
                            final number = double.tryParse(value);
                            if (number == null || number <= 0) {
                              return 'Введите корректное значение';
                            }
                            if (_selectedType == 'percent' && number > 100) {
                              return 'Процент не может быть больше 100';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _minOrderController,
                          decoration: const InputDecoration(
                            labelText: 'Мин. сумма заказа (необязательно)',
                            prefixIcon: Icon(Icons.shopping_cart),
                            border: OutlineInputBorder(),
                            suffixText: '₽',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final number = double.tryParse(value);
                              if (number == null || number < 0) {
                                return 'Введите корректную сумму';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _maxDiscountController,
                          decoration: const InputDecoration(
                            labelText: 'Макс. сумма скидки (необязательно)',
                            prefixIcon: Icon(Icons.money_off),
                            border: OutlineInputBorder(),
                            suffixText: '₽',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final number = double.tryParse(value);
                              if (number == null || number < 0) {
                                return 'Введите корректную сумму';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Действует с'),
                          subtitle: Text(_formatDate(_validFrom)),
                          trailing: const Icon(Icons.calendar_today),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Theme.of(context).colorScheme.outline),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _validFrom,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _validFrom = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Действует до'),
                          subtitle: Text(_formatDate(_validTo)),
                          trailing: const Icon(Icons.calendar_today),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Theme.of(context).colorScheme.outline),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _validTo,
                              firstDate: _validFrom,
                              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) {
                              setState(() => _validTo = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usageLimitController,
                          decoration: const InputDecoration(
                            labelText: 'Лимит использований (необязательно)',
                            prefixIcon: Icon(Icons.numbers),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final number = int.tryParse(value);
                              if (number == null || number <= 0) {
                                return 'Введите корректное число';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(widget.discount != null ? 'Сохранить' : 'Создать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;

    final discount = Discount(
      id: widget.discount?.id,
      code: _codeController.text.trim().toUpperCase(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      value: double.parse(_valueController.text),
      minOrderAmount: _minOrderController.text.isNotEmpty
          ? double.parse(_minOrderController.text)
          : null,
      maxDiscountAmount: _maxDiscountController.text.isNotEmpty
          ? double.parse(_maxDiscountController.text)
          : null,
      validFrom: _validFrom,
      validTo: _validTo,
      isActive: widget.discount?.isActive ?? true,
      usageLimit: _usageLimitController.text.isNotEmpty
          ? int.parse(_usageLimitController.text)
          : null,
      usageCount: widget.discount?.usageCount ?? 0,
      createdAt: widget.discount?.createdAt,
    );

    Navigator.pop(context, discount);
  }
}

class _DiscountDetailSheet extends StatelessWidget {
  final Discount discount;

  const _DiscountDetailSheet({required this.discount});

  @override
  Widget build(BuildContext context) {
    final valid = _isValidNow();
    final expired = _isExpired();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          discount.code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (discount.description.isNotEmpty)
                          Text(
                            discount.description,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: valid
                          ? Colors.green.withOpacity(0.1)
                          : expired
                              ? Colors.red.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: valid
                            ? Colors.green
                            : expired
                                ? Colors.red
                                : Colors.grey,
                      ),
                    ),
                    child: Text(
                      valid ? 'Действует' : expired ? 'Истекла' : 'Неизвестно',
                      style: TextStyle(
                        color: valid
                            ? Colors.green
                            : expired
                                ? Colors.red
                                : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Детали скидки',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                Icons.category,
                'Тип',
                discount.type == 'percent' ? 'Процент' : 'Фиксированная',
              ),
              _buildDetailRow(
                context,
                discount.type == 'percent' ? Icons.percent : Icons.money,
                'Значение',
                discount.type == 'percent'
                    ? '${discount.value.toStringAsFixed(0)}%'
                    : '${discount.value.toStringAsFixed(0)} ₽',
              ),
              if (discount.minOrderAmount != null)
                _buildDetailRow(
                  context,
                  Icons.shopping_cart,
                  'Мин. сумма заказа',
                  '${discount.minOrderAmount!.toStringAsFixed(0)} ₽',
                ),
              if (discount.maxDiscountAmount != null)
                _buildDetailRow(
                  context,
                  Icons.money_off,
                  'Макс. сумма скидки',
                  '${discount.maxDiscountAmount!.toStringAsFixed(0)} ₽',
                ),
              _buildDetailRow(
                context,
                Icons.calendar_today,
                'Действует с',
                _formatDate(discount.validFrom),
              ),
              _buildDetailRow(
                context,
                Icons.calendar_today,
                'Действует до',
                _formatDate(discount.validTo),
              ),
              _buildDetailRow(
                context,
                Icons.bar_chart,
                'Использований',
                discount.usageLimit != null
                    ? '${discount.usageCount} / ${discount.usageLimit}'
                    : '${discount.usageCount}',
              ),
              _buildDetailRow(
                context,
                Icons.toggle_on,
                'Статус',
                discount.isActive ? 'Активна' : 'Неактивна',
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isValidNow() {
    final now = DateTime.now();
    return now.isAfter(discount.validFrom) && now.isBefore(discount.validTo);
  }

  bool _isExpired() {
    return DateTime.now().isAfter(discount.validTo);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
