import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/order_repository.dart';
import '../../repositories/dish_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/waiter_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../models/order.dart';
import '../../models/dish.dart';
import '../receipt/receipt_view_screen.dart';
import '../../database/db_service.dart';

enum SearchCategory { orders, dishes, customers, waiters, expenses }

class SearchResult {
  final SearchCategory category;
  final String title;
  final String subtitle;
  final int? id;
  final dynamic rawData;

  const SearchResult({
    required this.category,
    required this.title,
    required this.subtitle,
    this.id,
    this.rawData,
  });
}

class SearchScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const SearchScreen({super.key, this.onNavigate});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _isLoading = false;
  String _query = '';
  List<SearchResult> _results = [];
  List<String> _recentSearches = [];
  static const _recentSearchesKey = 'recent_searches';
  static const _maxRecentSearches = 10;

  final _orderRepo = const OrderRepository();
  final _dishRepo = const DishRepository();
  final _customerRepo = const CustomerRepository();
  final _waiterRepo = const WaiterRepository();
  final _expenseRepo = const ExpenseRepository();

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentSearchesKey) ?? [];
    setState(() => _recentSearches = stored);
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final searches = List<String>.from(_recentSearches);
    searches.remove(query);
    searches.insert(0, query);
    if (searches.length > _maxRecentSearches) {
      searches.removeRange(_maxRecentSearches, searches.length);
    }
    setState(() => _recentSearches = searches);
    await prefs.setStringList(_recentSearchesKey, searches);
  }

  void _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = List<String>.from(_recentSearches);
    searches.remove(query);
    setState(() => _recentSearches = searches);
    await prefs.setStringList(_recentSearchesKey, searches);
  }

  void _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    setState(() => _recentSearches = []);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    _saveRecentSearch(value.trim());
    _performSearch(value);
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _query = query.trim();
      _isLoading = _query.isNotEmpty;
      if (_query.isEmpty) _results = [];
    });

    if (_query.isEmpty) return;

    try {
      final q = _query.toLowerCase();
      final results = <SearchResult>[];

      final ordersFuture = _searchOrders(q);
      final dishesFuture = _searchDishes(q);
      final customersFuture = _searchCustomers(q);
      final waitersFuture = _searchWaiters(q);
      final expensesFuture = _searchExpenses(q);

      final allResults = await Future.wait([
        ordersFuture,
        dishesFuture,
        customersFuture,
        waitersFuture,
        expensesFuture,
      ]);

      for (final group in allResults) {
        results.addAll(group);
      }

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<int, String>> _loadWaiterMap() async {
    final waiters = await _waiterRepo.getAll();
    final map = <int, String>{};
    for (final w in waiters) {
      if (w.id != null) map[w.id!] = w.name;
    }
    return map;
  }

  List<SearchResult> _orderResults(List<OrderModel> orders, Map<int, String> waiterMap) {
    return orders.map((o) {
      final dateStr = o.orderDate != null
          ? '${o.orderDate!.day.toString().padLeft(2, '0')}.${o.orderDate!.month.toString().padLeft(2, '0')}.${o.orderDate!.year}'
          : '';
      final waiterName = o.waiterId != null ? (waiterMap[o.waiterId!] ?? '') : '';
      return SearchResult(
        category: SearchCategory.orders,
        title: 'Заказ ${o.orderNumber}',
        subtitle:
            '$waiterName • $dateStr • ${_formatAmount(o.totalAmount)} ₽ • ${o.status}',
        id: o.id,
        rawData: o,
      );
    }).toList();
  }

  Future<List<SearchResult>> _searchOrders(String q) async {
    final orders = await _orderRepo.search(q);
    final waiterMap = await _loadWaiterMap();
    return _orderResults(orders, waiterMap);
  }

  Future<List<SearchResult>> _searchDishes(String q) async {
    final dishes = await _dishRepo.search(q);
    return dishes.map((d) {
      return SearchResult(
        category: SearchCategory.dishes,
        title: d.name,
        subtitle:
            '${_formatAmount(d.price)} ₽ • ${d.isActive ? 'Активно' : 'Неактивно'}',
        id: d.id,
        rawData: d,
      );
    }).toList();
  }

  Future<List<SearchResult>> _searchCustomers(String q) async {
    final customers = await _customerRepo.search(q);
    return customers.map((c) {
      final subtitle = [
        if (c.phone != null && c.phone!.isNotEmpty) c.phone,
        'Визитов: ${c.visitCount}',
        '${_formatAmount(c.totalSpent)} ₽',
      ].where((e) => e != null).join(' • ');
      return SearchResult(
        category: SearchCategory.customers,
        title: c.name,
        subtitle: subtitle,
        id: c.id,
        rawData: c,
      );
    }).toList();
  }

  Future<List<SearchResult>> _searchWaiters(String q) async {
    final waiters = await _waiterRepo.search(q);
    return waiters.map((w) {
      return SearchResult(
        category: SearchCategory.waiters,
        title: w.name,
        subtitle: '${w.role} • ${w.isActive ? 'Активен' : 'Неактивен'}',
        id: w.id,
        rawData: w,
      );
    }).toList();
  }

  Future<List<SearchResult>> _searchExpenses(String q) async {
    final expenses = await _expenseRepo.search(q);
    return expenses.map((e) {
      final dateStr =
          '${e.expenseDate.day.toString().padLeft(2, '0')}.${e.expenseDate.month.toString().padLeft(2, '0')}.${e.expenseDate.year}';
      return SearchResult(
        category: SearchCategory.expenses,
        title: e.description,
        subtitle: '${e.category} • ${_formatAmount(e.amount)} ₽ • $dateStr',
        id: e.id,
        rawData: e,
      );
    }).toList();
  }

  Future<void> _executeQuickFilter(String label, Future<List<SearchResult>> Function() filter) async {
    setState(() {
      _query = label;
      _isLoading = true;
      _results = [];
    });
    _searchController.text = label;
    try {
      final results = await filter();
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<SearchResult>> _filterTodayOrders() async {
    final today = DateTime.now();
    final datePrefix = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final rows = await DbService.instance.query('''
      SELECT o.*, w.name as waiter_name, t.table_number
      FROM orders o
      LEFT JOIN waiters w ON w.id = o.waiter_id
      LEFT JOIN restaurant_tables t ON t.id = o.table_id
      WHERE o.order_date LIKE ?
      ORDER BY o.order_date DESC
    ''', arguments: ['$datePrefix%']);
    final orders = rows.map(OrderModel.fromMap).toList();
    final waiterMap = await _loadWaiterMap();
    return _orderResults(orders, waiterMap);
  }

  Future<List<SearchResult>> _filterNewOrders() async {
    final orders = await _orderRepo.getByStatus('Новый');
    final waiterMap = await _loadWaiterMap();
    return _orderResults(orders, waiterMap);
  }

  Future<List<SearchResult>> _filterPopularDishes() async {
    final rows = await DbService.instance.query('''
      SELECT d.*, COALESCE(SUM(oi.quantity), 0) as order_count
      FROM dishes d
      LEFT JOIN order_items oi ON oi.dish_id = d.id
      GROUP BY d.id
      ORDER BY order_count DESC
      LIMIT 20
    ''');
    final dishes = rows.map(Dish.fromMap).toList();
    return dishes.map((d) {
      return SearchResult(
        category: SearchCategory.dishes,
        title: d.name,
        subtitle: '${_formatAmount(d.price)} ₽ • ${d.isActive ? 'Активно' : 'Неактивно'}',
        id: d.id,
        rawData: d,
      );
    }).toList();
  }

  void _navigateToSection(SearchCategory category) {
    const sectionMap = {
      SearchCategory.orders: 4,
      SearchCategory.dishes: 3,
      SearchCategory.customers: 14,
      SearchCategory.waiters: 6,
      SearchCategory.expenses: 10,
    };
    final index = sectionMap[category];
    if (index != null) {
      widget.onNavigate?.call(index);
      Navigator.of(context).maybePop();
    }
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  IconData _categoryIcon(SearchCategory category) {
    switch (category) {
      case SearchCategory.orders:
        return Icons.receipt_long_outlined;
      case SearchCategory.dishes:
        return Icons.restaurant_menu_outlined;
      case SearchCategory.customers:
        return Icons.person_outline;
      case SearchCategory.waiters:
        return Icons.supervisor_account_outlined;
      case SearchCategory.expenses:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Color _categoryColor(SearchCategory category, ColorScheme scheme) {
    switch (category) {
      case SearchCategory.orders:
        return scheme.primary;
      case SearchCategory.dishes:
        return scheme.tertiary;
      case SearchCategory.customers:
        return scheme.secondary;
      case SearchCategory.waiters:
        return scheme.error;
      case SearchCategory.expenses:
        return scheme.errorContainer;
    }
  }

  String _categoryLabel(SearchCategory category) {
    switch (category) {
      case SearchCategory.orders:
        return 'Заказы';
      case SearchCategory.dishes:
        return 'Блюда';
      case SearchCategory.customers:
        return 'Клиенты';
      case SearchCategory.waiters:
        return 'Официанты';
      case SearchCategory.expenses:
        return 'Расходы';
    }
  }

  Map<SearchCategory, List<SearchResult>> get _groupedResults {
    final map = <SearchCategory, List<SearchResult>>{};
    for (final r in _results) {
      map.putIfAbsent(r.category, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildSearchBar(scheme),
          Expanded(
            child: _query.isEmpty
                ? _buildInitialView(scheme)
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildResultsView(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: scheme.surface,
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmitted,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Имя официанта, блюдо, клиент...',
          hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
          prefixIcon: const Icon(Icons.search),
          prefixIconColor: scheme.onSurfaceVariant,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _results = [];
                    });
                    _focusNode.requestFocus();
                  },
                )
              : null,
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildInitialView(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          _buildRecentSearches(scheme),
          const SizedBox(height: 16),
        ],
        _buildQuickFilters(scheme),
      ],
    );
  }

  Widget _buildRecentSearches(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Недавние запросы',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _clearRecentSearches,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Очистить',
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _recentSearches.map((s) {
            return InputChip(
              label: Text(s, style: const TextStyle(fontSize: 13)),
              avatar: Icon(Icons.history, size: 16, color: scheme.onSurfaceVariant),
              deleteIcon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
              onDeleted: () => _removeRecentSearch(s),
              onPressed: () {
                _searchController.text = s;
                _onSearchSubmitted(s);
              },
              backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickFilters(ColorScheme scheme) {
    final filters = [
      ('Заказы за сегодня', Icons.today, _filterTodayOrders),
      ('Новые заказы', Icons.fiber_new_outlined, _filterNewOrders),
      ('Популярные блюда', Icons.trending_up_outlined, _filterPopularDishes),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Быстрые фильтры',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((f) {
            return ActionChip(
              avatar: Icon(f.$2, size: 18),
              label: Text(f.$1, style: const TextStyle(fontSize: 13)),
              onPressed: () => _executeQuickFilter(f.$1, f.$3),
              backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultsView(ColorScheme scheme) {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: scheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              'Ничего не найдено',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'По запросу «$_query»',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.35),
                  ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupedResults;
    final categories = [
      SearchCategory.orders,
      SearchCategory.dishes,
      SearchCategory.customers,
      SearchCategory.waiters,
      SearchCategory.expenses,
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: categories.fold<int>(0, (sum, c) => sum + (grouped[c]?.isNotEmpty == true ? 1 + grouped[c]!.length : 0)),
      itemBuilder: (context, index) {
        int running = 0;
        for (final cat in categories) {
          final items = grouped[cat];
          if (items == null || items.isEmpty) continue;

          if (running == index) {
            return _buildCategoryHeader(cat, items.length, scheme);
          }
          running++;

          if (running == index) {
            return Column(
              children: items.map((r) => _buildResultTile(r, scheme)).toList(),
            );
          }
          running += items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCategoryHeader(
      SearchCategory category, int count, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(_categoryIcon(category), size: 20, color: _categoryColor(category, scheme)),
          const SizedBox(width: 8),
          Text(
            _categoryLabel(category),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _categoryColor(category, scheme),
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: _categoryColor(category, scheme).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _categoryColor(category, scheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(SearchResult result, ColorScheme scheme) {
    final iconColor = _categoryColor(result.category, scheme);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_categoryIcon(result.category), size: 22, color: iconColor),
      ),
      title: Text(
        result.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        result.subtitle,
        style: TextStyle(
          fontSize: 13,
          color: scheme.onSurface.withOpacity(0.55),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: scheme.onSurface.withOpacity(0.3),
      ),
      onTap: () {
        _showSearchResultDetail(result);
      },
    );
  }

  void _showSearchResultDetail(SearchResult result) {
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
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(_categoryIcon(result.category), color: _categoryColor(result.category, Theme.of(context).colorScheme)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _categoryColor(result.category, Theme.of(context).colorScheme).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_categorySingularLabel(result.category), style: TextStyle(fontSize: 12, color: _categoryColor(result.category, Theme.of(context).colorScheme))),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ..._buildDetailRows(result),
            const SizedBox(height: 16),
            if (result.category == SearchCategory.orders && result.rawData != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptViewScreen(order: result.rawData)));
                  },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Просмотр чека'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            if (result.category == SearchCategory.orders) const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToSection(result.category);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Перейти к разделу'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDetailRows(SearchResult result) {
    final data = result.rawData;
    if (data == null) return [];

    switch (result.category) {
      case SearchCategory.orders:
        return [
          _detailRow('Номер', data.orderNumber?.toString() ?? ''),
          _detailRow('Статус', data.status?.toString() ?? ''),
          _detailRow('Сумма', '${data.totalAmount?.toStringAsFixed(2) ?? '0'} ₽'),
          if (data.finalAmount != null && data.finalAmount != data.totalAmount)
            _detailRow('Итого', '${data.finalAmount.toStringAsFixed(2)} ₽'),
          if (data.discountAmount != null && data.discountAmount > 0)
            _detailRow('Скидка', '-${data.discountAmount.toStringAsFixed(0)} ₽'),
          _detailRow('Оплата', data.paymentMethod?.toString() ?? '—'),
          _detailRow('Дата', data.orderDate?.toString().substring(0, 16) ?? '—'),
          if (data.waiterId != null) _detailRow('Официант', '#${data.waiterId}'),
          if (data.tableId != null) _detailRow('Стол', '#${data.tableId}'),
          if (data.notes != null && data.notes!.isNotEmpty) _detailRow('Заметки', data.notes!),
        ];
      case SearchCategory.dishes:
        return [
          _detailRow('Категория', result.subtitle),
          _detailRow('Цена', '${data.price?.toStringAsFixed(2) ?? '0'} ₽'),
          if (data.volume != null && data.volume.toString().isNotEmpty)
            _detailRow('Объём', '${data.volume} ${data.unit ?? 'шт'}'),
          if (data.description != null && data.description.toString().isNotEmpty)
            _detailRow('Описание', data.description.toString()),
          _detailRow('Статус', (data.isActive ?? true) ? 'Активно' : 'Неактивно'),
        ];
      case SearchCategory.customers:
        return [
          if (data.phone != null) _detailRow('Телефон', data.phone.toString()),
          if (data.email != null) _detailRow('Эл. почта', data.email.toString()),
          _detailRow('Визитов', '${data.visitCount ?? 0}'),
          _detailRow('Потрачено', '${data.totalSpent?.toStringAsFixed(0) ?? '0'} ₽'),
          if (data.lastVisit != null) _detailRow('Последний визит', data.lastVisit.toString().substring(0, 10)),
          if (data.allergies != null && data.allergies.toString().isNotEmpty) _detailRow('Аллергии', data.allergies.toString()),
          if (data.notes != null && data.notes.toString().isNotEmpty) _detailRow('Заметки', data.notes.toString()),
        ];
      case SearchCategory.waiters:
        return [
          _detailRow('Роль', data.role?.toString() ?? ''),
          _detailRow('Статус', (data.isActive ?? true) ? 'Активен' : 'Неактивен'),
          if (data.phone != null) _detailRow('Телефон', data.phone.toString()),
          if (data.email != null) _detailRow('Эл. почта', data.email.toString()),
        ];
      case SearchCategory.expenses:
        return [
          _detailRow('Категория', data.category?.toString() ?? ''),
          _detailRow('Описание', data.description?.toString() ?? ''),
          _detailRow('Сумма', '${data.amount?.toStringAsFixed(2) ?? '0'} ₽'),
          _detailRow('Дата', data.expenseDate?.toString().substring(0, 10) ?? ''),
          if (data.supplier != null && data.supplier.toString().isNotEmpty) _detailRow('Поставщик', data.supplier.toString()),
          if (data.receiptNumber != null && data.receiptNumber.toString().isNotEmpty) _detailRow('Чек №', data.receiptNumber.toString()),
        ];
    }
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.end)),
      ],
    ),
  );

  String _categorySingularLabel(SearchCategory category) {
    switch (category) {
      case SearchCategory.orders: return 'Заказ';
      case SearchCategory.dishes: return 'Блюдо';
      case SearchCategory.customers: return 'Клиент';
      case SearchCategory.waiters: return 'Официант';
      case SearchCategory.expenses: return 'Расход';
    }
  }
}
