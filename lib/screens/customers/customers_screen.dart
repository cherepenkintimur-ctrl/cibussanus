import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _repo = const CustomerRepository();
  final _orderRepo = const OrderRepository();
  final _searchController = TextEditingController();
  List<Customer> _customers = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';

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
      final customers = _searchQuery.isEmpty
          ? await _repo.getAll()
          : await _repo.search(_searchQuery);
      final stats = await _repo.getCustomerStats();
      setState(() {
        _customers = customers;
        _stats = stats;
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

  Future<void> _onSearch(String query) async {
    _searchQuery = query.trim();
    await _loadData();
  }

  void _showCreateDialog() {
    _showCustomerDialog();
  }

  void _showEditDialog(Customer customer) {
    _showCustomerDialog(customer: customer);
  }

  void _showCustomerDialog({Customer? customer}) {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');
    final allergiesController = TextEditingController(text: customer?.allergies ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer == null ? 'Новый клиент' : 'Редактировать клиента'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Эл. почта',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Заметки',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: allergiesController,
                decoration: const InputDecoration(
                  labelText: 'Аллергии',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning_amber),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите имя клиента')),
                );
                return;
              }
              final newCustomer = Customer(
                id: customer?.id,
                name: nameController.text.trim(),
                phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                allergies: allergiesController.text.trim().isEmpty ? null : allergiesController.text.trim(),
                visitCount: customer?.visitCount ?? 0,
                totalSpent: customer?.totalSpent ?? 0,
                lastVisit: customer?.lastVisit,
                createdAt: customer?.createdAt,
              );
              try {
                if (customer == null) {
                  await _repo.create(newCustomer);
                } else {
                  await _repo.update(newCustomer);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            child: Text(customer == null ? 'Создать' : 'Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: Text('Вы уверены, что хотите удалить «${customer.name}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _repo.delete(customer.id!);
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

  void _showCustomerDetail(Customer customer) {
    final tierData = _getTierData(customer.loyaltyTier);
    final nextTier = _getNextTier(customer);
    final progress = _getTierProgress(customer, nextTier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: tierData['color'] as Color,
                    child: Text(
                      customer.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 24, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (tierData['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            customer.loyaltyTier,
                            style: TextStyle(
                              color: tierData['color'] as Color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditDialog(customer);
                    },
                    icon: const Icon(Icons.edit),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (nextTier != null) ...[
                Text(
                  'Прогресс до уровня «$nextTier»',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(tierData['color'] as Color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
              _buildInfoRow(Icons.phone, 'Телефон', customer.phone ?? '—'),
              _buildInfoRow(Icons.email, 'Эл. почта', customer.email ?? '—'),
              _buildInfoRow(Icons.star, 'Визитов', '${customer.visitCount}'),
              _buildInfoRow(Icons.attach_money, 'Потрачено', '${customer.totalSpent.toStringAsFixed(0)} ₽'),
              _buildInfoRow(Icons.calendar_today, 'Последний визит',
                  customer.lastVisit != null ? _formatDate(customer.lastVisit!) : '—'),
              _buildInfoRow(Icons.person_add, 'Создан',
                  customer.createdAt != null ? _formatDate(customer.createdAt!) : '—'),
              if (customer.allergies != null && customer.allergies!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text('Аллергии', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(customer.allergies!, style: const TextStyle(color: Colors.red)),
                ),
              ],
              if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notes, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                    const SizedBox(width: 8),
                    const Text('Заметки', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(customer.notes!),
                ),
              ],
              if (customer.email != null && customer.createdAt != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.history, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Клиент с ${_formatDate(customer.createdAt!)}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getCustomerTenure(customer.createdAt!),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
              if (customer.id != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                    const SizedBox(width: 8),
                    const Text('Последние заказы', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<OrderModel>>(
                  future: _orderRepo.getByCustomerId(customer.id!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Заказов пока нет',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Column(
                      children: orders.map((order) => _buildOrderRow(order)).toList(),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteCustomer(customer);
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.delete),
                  label: const Text('Удалить клиента'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTierData(String tier) {
    if (tier.contains('Платиновый')) {
      return {'color': const Color(0xFF7B1FA2), 'icon': '💎'};
    } else if (tier.contains('Золотой')) {
      return {'color': const Color(0xFFF9A825), 'icon': '🥇'};
    } else if (tier.contains('Серебряный')) {
      return {'color': const Color(0xFF78909C), 'icon': '🥈'};
    } else if (tier.contains('Бронзовый')) {
      return {'color': const Color(0xFFC9A96E), 'icon': '🥉'};
    }
    return {'color': const Color(0xFF9E9E9E), 'icon': ''};
  }

  String? _getNextTier(Customer customer) {
    final tier = customer.loyaltyTier;
    if (tier.contains('Платиновый')) return null;
    if (tier.contains('Золотой')) return 'Платиновый';
    if (tier.contains('Серебряный')) return 'Золотой';
    if (tier.contains('Бронзовый')) return 'Серебряный';
    return 'Бронзовый';
  }

  double _getTierProgress(Customer customer, String? nextTier) {
    if (nextTier == null) return 1.0;
    switch (nextTier) {
      case 'Бронзовый':
        return customer.visitCount / 3.0;
      case 'Серебряный':
        return customer.visitCount / 10.0;
      case 'Золотой':
        return customer.totalSpent / 50000.0;
      case 'Платиновый':
        return customer.totalSpent / 100000.0;
      default:
        return 0.0;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _getCustomerTenure(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inDays < 1) return 'Менее дня';
    if (difference.inDays < 30) return '${difference.inDays} дн. назад';
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months мес. назад';
    }
    final years = (difference.inDays / 365).floor();
    final remainingMonths = ((difference.inDays % 365) / 30).floor();
    if (remainingMonths == 0) return '$years год(а) назад';
    return '$years год. $remainingMonths мес. назад';
  }

  Widget _buildOrderRow(OrderModel order) {
    final statusColor = _getOrderStatusColor(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (order.orderDate != null)
                  Text(
                    _formatDate(order.orderDate!),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            '${order.finalAmount.toStringAsFixed(0)} ₽',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              order.status,
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'Новый':
        return Colors.blue;
      case 'Готовится':
        return Colors.orange;
      case 'Готов':
        return Colors.green;
      case 'Оплачен':
        return Colors.grey;
      case 'Отменён':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCustomers = _stats['total_customers'] ?? 0;
    final totalRevenue = (_stats['total_revenue'] ?? 0.0).toDouble();
    final avgSpent = (_stats['avg_spent'] ?? 0.0).toDouble();
    final tierRows = (_stats['by_tier'] ?? []) as List;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Клиенты'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.person_add),
            tooltip: 'Добавить клиента',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск по имени, телефону, email...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onSearch,
                  ),
                  const SizedBox(height: 16),

                  // Stats summary
                  Row(
                    children: [
                      _buildStatCard(
                        'Всего клиентов',
                        '$totalCustomers',
                        Icons.people,
                        Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Общая выручка',
                        '${totalRevenue.toStringAsFixed(0)} ₽',
                        Icons.trending_up,
                        const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        'Средний чек',
                        '${avgSpent.toStringAsFixed(0)} ₽',
                        Icons.receipt,
                        const Color(0xFF1565C0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tier breakdown
                  if (tierRows.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Уровни лояльности',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...tierRows.map((row) {
                            final tierName = row['tier']?.toString() ?? '';
                            final count = row['count'] ?? 0;
                            final icon = _getTierIcon(tierName);
                            final color = _getTierColor(tierName);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(icon, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tierName,
                                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Customer list
                  if (_customers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'Нет клиентов' : 'Ничего не найдено',
                              style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._customers.map((customer) => _buildCustomerCard(customer)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    final tierData = _getTierData(customer.loyaltyTier);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCustomerDetail(customer),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: tierData['color'] as Color,
                    child: Text(
                      customer.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (customer.phone != null)
                          Text(
                            customer.phone!,
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        if (customer.email != null)
                          Text(
                            customer.email!,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (tierData['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      customer.loyaltyTier,
                      style: TextStyle(
                        color: tierData['color'] as Color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildMiniStat(Icons.how_to_reg, '${customer.visitCount} визитов'),
                  const SizedBox(width: 12),
                  _buildMiniStat(Icons.attach_money, '${customer.totalSpent.toStringAsFixed(0)} ₽'),
                  const SizedBox(width: 12),
                  _buildMiniStat(Icons.calendar_today,
                      customer.lastVisit != null ? _formatDate(customer.lastVisit!) : '—'),
                ],
              ),
              if (customer.allergies != null && customer.allergies!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          customer.allergies!,
                          style: const TextStyle(fontSize: 11, color: Colors.red),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  customer.notes!,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  String _getTierIcon(String tier) {
    if (tier.contains('Платиновый')) return '💎';
    if (tier.contains('Золотой')) return '🥇';
    if (tier.contains('Серебряный')) return '🥈';
    if (tier.contains('Бронзовый')) return '🥉';
    return '👤';
  }

  Color _getTierColor(String tier) {
    if (tier.contains('Платиновый')) return const Color(0xFF7B1FA2);
    if (tier.contains('Золотой')) return const Color(0xFFF9A825);
    if (tier.contains('Серебряный')) return const Color(0xFF78909C);
    if (tier.contains('Бронзовый')) return const Color(0xFFC9A96E);
    return const Color(0xFF9E9E9E);
  }
}
