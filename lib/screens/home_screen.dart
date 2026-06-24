import 'package:flutter/material.dart';

import 'database/categories_screen.dart';
import 'database/dishes_screen.dart';
import 'orders/orders_screen.dart';
import 'reports/reports_screen.dart';
import 'info/info_screen.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  late final List<Widget> pages = [
    const CategoriesScreen(),
    const DishesScreen(),
    const OrdersScreen(),
    const ReportsScreen(),
    const InfoScreen(),
  ];

  static const List<String> titles = [
    'Категории',
    'Блюда',
    'Заказы',
    'Отчеты',
    'Справка',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CibusSanus • ${titles[selectedIndex]}'),
        centerTitle: false,
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