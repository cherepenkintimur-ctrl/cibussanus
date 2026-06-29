import 'package:flutter/material.dart';

import '../../database/db_service.dart';
import '../../models/dish.dart';
import '../../models/waiter.dart';
import '../../models/restaurant_table.dart';
import '../../models/category.dart';
import '../../repositories/dish_repository.dart';
import '../../repositories/waiter_repository.dart';
import '../../repositories/table_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../models/expense.dart';

class CrudHubScreen extends StatefulWidget {
  const CrudHubScreen({super.key});

  @override
  State<CrudHubScreen> createState() => _CrudHubScreenState();
}

class _CrudHubScreenState extends State<CrudHubScreen> {
  String _selectedSection = 'dish';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final _dishRepo = const DishRepository();
  final _waiterRepo = const WaiterRepository();
  final _tableRepo = const TableRepository();
  final _categoryRepo = const CategoryRepository();
  final _expenseRepo = const ExpenseRepository();

  late Future<List<Map<String, dynamic>>> _dishesFuture;
  late Future<List<Waiter>> _waitersFuture;
  late Future<List<Expense>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _dishesFuture = _loadDishes();
    _waitersFuture = _waiterRepo.getAll();
    _expensesFuture = _loadRecentExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: PopupMenuButton<String>(
        onSelected: (v) {
          switch (v) {
            case 'dish': _showDishDialog(); break;
            case 'category': _showCategoryDialog(); break;
            case 'waiter': _showWaiterDialog(); break;
            case 'table': _showTableDialog(); break;
            case 'expense': _showExpenseDialog(); break;
          }
        },
        itemBuilder: (_) {
          switch (_selectedSection) {
            case 'dish': return [
              const PopupMenuItem(value: 'dish', child: Text('Блюдо')),
              const PopupMenuItem(value: 'category', child: Text('Категория')),
            ];
            case 'staff': return [
              const PopupMenuItem(value: 'waiter', child: Text('Официант')),
              const PopupMenuItem(value: 'table', child: Text('Столик')),
            ];
            default: return [
              const PopupMenuItem(value: 'expense', child: Text('Расход')),
            ];
          }
        },
        child: FloatingActionButton(
          mini: true,
          onPressed: null,
          child: const Icon(Icons.add, size: 20),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                _sectionTab('dish', 'Блюда', Icons.restaurant_menu),
                _sectionTab('staff', 'Персонал', Icons.people),
                _sectionTab('finance', 'Финансы', Icons.account_balance_wallet),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _selectedSection == 'dish' ? _buildDishList()
                : _selectedSection == 'staff' ? _buildStaffList()
                : _buildFinanceList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionTab(String id, String label, IconData icon) {
    final isSelected = _selectedSection == id;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FilterChip(
          avatar: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedSection = id),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildDishList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dishesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: Text('Нет данных'));
        final dishes = snapshot.data!;
        final filtered = _searchQuery.isEmpty
            ? dishes
            : dishes.where((d) {
                final q = _searchQuery.toLowerCase();
                final name = (d['name']?.toString() ?? '').toLowerCase();
                final cat = (d['category_name']?.toString() ?? '').toLowerCase();
                final vol = (d['volume']?.toString() ?? '').toLowerCase();
                return name.contains(q) || cat.contains(q) || vol.contains(q);
              }).toList();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final d = filtered[i];
            final price = ((d['price'] as num?) ?? 0).toDouble();
            final cost = ((d['cost_price'] as num?) ?? 0).toDouble();
            final margin = price > 0 ? ((price - cost) / price * 100) : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(d['name']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text('${price.toStringAsFixed(0)} ₽ · ${d['category_name'] ?? ''}', style: const TextStyle(fontSize: 11)),
                onTap: () => _showDishDetails(d),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${margin.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: margin > 30 ? Colors.green : Colors.orange)),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Изменить', style: TextStyle(fontSize: 12))),
                        const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(fontSize: 12, color: Colors.red))),
                      ],
                      onSelected: (v) async {
                        if (v == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Удалить блюдо?'),
                              content: Text('«${d['name']}» будет удалено'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _dishRepo.delete(d['id'] as int);
                            setState(() => _refreshData());
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStaffList() {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: FutureBuilder<List<Waiter>>(
            future: _waitersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: Text('Нет данных'));
              final waiters = snapshot.data!;
              final filtered = _searchQuery.isEmpty
                  ? waiters
                  : waiters.where((w) => w.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final w = filtered[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 3),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: w.isActive ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                        child: Text(w.name[0], style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(w.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${w.role} · ${w.baseSalary.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 11)),
                      onTap: () => _showWaiterDetails(w),
                      trailing: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Изменить', style: TextStyle(fontSize: 12))),
                        ],
                        onSelected: (v) {
                          if (v == 'edit') _showWaiterDialog(waiter: w);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceList() {
    return FutureBuilder<List<Expense>>(
      future: _expensesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: Text('Нет данных'));
        final expenses = snapshot.data!;
        final filtered = _searchQuery.isEmpty
            ? expenses
            : expenses.where((e) => e.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final e = filtered[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 3),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  child: const Icon(Icons.receipt, size: 14, color: Colors.orange),
                ),
                title: Text(e.description, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${e.category} · ${e.expenseDate.day}.${e.expenseDate.month}.${e.expenseDate.year}', style: const TextStyle(fontSize: 11)),
                onTap: () => _showExpenseDetails(e),
                trailing: Text('${e.amount.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadDishes() async {
    final db = DbService.instance.database;
    return db.rawQuery('''
      SELECT d.*, c.name as category_name
      FROM dishes d
      LEFT JOIN categories c ON c.id = d.category_id
      WHERE d.is_active = 1
      ORDER BY d.name
    ''');
  }

  Future<List<Expense>> _loadRecentExpenses() async {
    final all = await _expenseRepo.getAll();
    return all.take(50).toList();
  }

  void _showDishDetails(Map<String, dynamic> d) {
    final price = ((d['price'] as num?) ?? 0).toDouble();
    final cost = ((d['cost_price'] as num?) ?? 0).toDouble();
    final margin = price > 0 ? ((price - cost) / price * 100) : 0.0;
    final volume = d['volume']?.toString() ?? '';
    final unit = d['unit']?.toString() ?? 'шт';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d['name']?.toString() ?? ''),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Категория', d['category_name']?.toString() ?? '—'),
              _infoRow('Цена', '${price.toStringAsFixed(0)} ₽'),
              _infoRow('Себестоимость', '${cost.toStringAsFixed(0)} ₽'),
              _infoRow('Маржа', '${margin.toStringAsFixed(0)}%'),
              if (volume.isNotEmpty) _infoRow('Объём', '$volume $unit'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _showDishDialog() async {
    final categories = await _categoryRepo.getAll();
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    int? selectedCatId;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новое блюдо'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()), autofocus: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder()),
                items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => selectedCatId = v,
              ),
              const SizedBox(height: 12),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Цена', suffixText: '₽', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Себестоимость', suffixText: '₽', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (nameCtrl.text.isEmpty || price <= 0) return;
              await _dishRepo.create(Dish(
                name: nameCtrl.text,
                categoryId: selectedCatId,
                price: price,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() => _refreshData());
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryDialog() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              await _categoryRepo.create(Category(name: nameCtrl.text));
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() => _refreshData());
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWaiterDialog({Waiter? waiter}) async {
    final nameCtrl = TextEditingController(text: waiter?.name ?? '');
    final phoneCtrl = TextEditingController(text: waiter?.phone ?? '');
    final roleCtrl = TextEditingController(text: waiter?.role ?? 'Официант');
    final salaryCtrl = TextEditingController(text: waiter?.baseSalary.toString() ?? '36000');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(waiter != null ? 'Редактировать' : 'Новый официант'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()), autofocus: true),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Телефон', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Должность', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: 'Оклад', suffixText: '₽', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final salary = double.tryParse(salaryCtrl.text) ?? 36000;
              if (waiter != null) {
                await _waiterRepo.update(Waiter(
                  id: waiter.id,
                  name: nameCtrl.text,
                  phone: phoneCtrl.text,
                  role: roleCtrl.text,
                  baseSalary: salary,
                  isActive: waiter.isActive,
                  hireDate: waiter.hireDate,
                ));
              } else {
                await _waiterRepo.create(Waiter(
                  name: nameCtrl.text,
                  phone: phoneCtrl.text,
                  email: '',
                  role: roleCtrl.text,
                  baseSalary: salary,
                  isActive: true,
                  hireDate: DateTime.now(),
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() => _refreshData());
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showWaiterDetails(Waiter w) async {
    final db = DbService.instance.database;
    final orders = await db.rawQuery(
      'SELECT COUNT(*) as cnt, COALESCE(SUM(total_amount), 0) as total FROM orders WHERE waiter_id = ?',
      [w.id],
    );
    final o = orders.isNotEmpty ? orders.first : {};
    final cnt = o['cnt'] ?? 0;
    final total = ((o['total'] as num?) ?? 0).toDouble();

    final tipsResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as tips FROM tips WHERE waiter_id = ?',
      [w.id],
    );
    final tips = ((tipsResult.isNotEmpty ? tipsResult.first['tips'] : 0) as num?)?.toDouble() ?? 0.0;

    final recentOrders = await db.rawQuery(
      '''SELECT o.order_number, o.total_amount, o.order_date, o.status
         FROM orders o WHERE o.waiter_id = ? ORDER BY o.order_date DESC LIMIT 5''',
      [w.id],
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(w.name),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Должность', w.role),
                _infoRow('Телефон', (w.phone?.isNotEmpty ?? false) ? w.phone! : '—'),
                _infoRow('Эл. почта', (w.email?.isNotEmpty ?? false) ? w.email! : '—'),
                _infoRow('Оклад', '${w.baseSalary.toStringAsFixed(0)} ₽'),
                _infoRow('Статус', w.isActive ? 'Активен' : 'Неактивен'),
                const Divider(height: 16),
                _infoRow('Заказов', '$cnt'),
                _infoRow('Выручка', '${total.toStringAsFixed(0)} ₽'),
                _infoRow('Чаевые', '${tips.toStringAsFixed(0)} ₽'),
                if (recentOrders.isNotEmpty) ...[
                  const Divider(height: 16),
                  const Text('Последние заказы', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  ...recentOrders.map((ro) {
                    final date = ro['order_date']?.toString() ?? '';
                    final dateShort = date.length >= 10 ? date.substring(5, 10) : date;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text('${ro['order_number']}', style: const TextStyle(fontSize: 11))),
                          Expanded(flex: 2, child: Text(dateShort, style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
                          Expanded(flex: 2, child: Text('${(ro['total_amount'] ?? 0)} ₽', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.end)),
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

  Future<void> _showTableDialog() async {
    final numCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '2');
    final zoneCtrl = TextEditingController(text: 'Основной зал');
    final zones = ['Основной зал', 'Терраса', 'Банкетный зал', 'VIP зона', 'У бара'];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый столик'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Номер стола', border: OutlineInputBorder()), autofocus: true, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Вместимость', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: zoneCtrl.text,
                decoration: const InputDecoration(labelText: 'Зона', border: OutlineInputBorder()),
                items: zones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
                onChanged: (v) { if (v != null) zoneCtrl.text = v; },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final num = int.tryParse(numCtrl.text) ?? 0;
              final cap = int.tryParse(capCtrl.text) ?? 2;
              if (num <= 0) return;
              await _tableRepo.create(RestaurantTable(
                tableNumber: num,
                capacity: cap,
                zone: zoneCtrl.text,
                status: 'Свободен',
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() => _refreshData());
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showExpenseDetails(Expense e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Расход'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Описание', e.description),
              _infoRow('Категория', e.category),
              _infoRow('Сумма', '${e.amount.toStringAsFixed(0)} ₽'),
              _infoRow('Дата', '${e.expenseDate.day}.${e.expenseDate.month}.${e.expenseDate.year}'),
              if (e.receiptNumber != null && e.receiptNumber!.isNotEmpty) _infoRow('Чек №', e.receiptNumber!),
              if (e.supplier != null && e.supplier!.isNotEmpty) _infoRow('Поставщик', e.supplier!),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _showExpenseDialog() async {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Продукты');
    final categories = ['Продукты', 'Зарплата', 'Коммунальные', 'Оборудование', 'Маркетинг', 'Другое'];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый расход'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: catCtrl.text,
                decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder()),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { if (v != null) catCtrl.text = v; },
              ),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder()), autofocus: true),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Сумма', suffixText: '₽', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              await _expenseRepo.create(Expense(
                category: catCtrl.text,
                description: descCtrl.text,
                amount: amount,
                expenseDate: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() => _refreshData());
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}
