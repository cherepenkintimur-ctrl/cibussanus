import 'package:flutter/material.dart';

import 'database/categories_screen.dart';
import 'database/dishes_screen.dart';
import 'orders/orders_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'waiters/waiters_screen.dart';
import 'tables/tables_screen.dart';
import 'tips/tips_screen.dart';
import 'shifts/shifts_screen.dart';
import 'expenses/expenses_screen.dart';
import 'analytics/advanced_analytics_screen.dart';
import 'discounts/discounts_screen.dart';
import 'kitchen/kitchen_screen.dart';
import 'reports/reports_screen.dart';
import 'reports/profit_loss_screen.dart';
import 'info/info_screen.dart';
import 'customers/customers_screen.dart';
import 'cash_register/cash_register_screen.dart';
import 'inventory/inventory_screen.dart';
import 'schedule/schedule_screen.dart';
import 'search/search_screen.dart';
import 'receipt/receipt_view_screen.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import 'crud_hub/crud_hub_screen.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  late final List<Widget> pages = [
    const DashboardScreen(),
    const CrudHubScreen(),
    const CategoriesScreen(),
    const DishesScreen(),
    const OrdersScreen(),
    const KitchenScreen(),
    const WaitersScreen(),
    const TablesScreen(),
    const TipsScreen(),
    const ShiftsScreen(),
    const ExpensesScreen(),
    const DiscountsScreen(),
    const ReportsScreen(),
    const ProfitLossScreen(),
    const AdvancedAnalyticsScreen(),
    const CustomersScreen(),
    const CashRegisterScreen(),
    const InventoryScreen(),
    const ScheduleScreen(),
    const CalendarScreen(),
    const SearchScreen(),
    const SettingsScreen(),
    const InfoScreen(),
  ];

  static const List<String> titles = [
    'Панель управления',
    'Управление данными',
    'Категории',
    'Блюда',
    'Заказы',
    'Кухня',
    'Официанты',
    'Столики и бронь',
    'Чаевые',
    'Смены',
    'Расходы',
    'Скидки',
    'Базовые отчёты',
    'Выручка и прибыль',
    'Аналитика',
    'Клиенты',
    'Касса',
    'Склад',
    'График смен',
    'Календарь',
    'Поиск',
    'Настройки',
    'Справка',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CibusSanus  •  ${titles[selectedIndex]}'),
        centerTitle: false,
        elevation: 0,
        actions: [
          if (selectedIndex != 21)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Поиск',
              onPressed: () => setState(() => selectedIndex = 20),
            ),
          if (selectedIndex != 21)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Настройки',
              onPressed: () => setState(() => selectedIndex = 21),
            ),
        ],
      ),
      drawer: AppDrawer(
        selectedIndex: selectedIndex,
        onSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
    );
  }
}
