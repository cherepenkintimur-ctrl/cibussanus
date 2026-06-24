import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.restaurant,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CibusSanus',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Учет продаж ресторана европейской кухни',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _tile(
                    context,
                    icon: Icons.category_outlined,
                    title: 'Категории',
                    index: 0,
                  ),
                  _tile(
                    context,
                    icon: Icons.restaurant_menu_outlined,
                    title: 'Блюда',
                    index: 1,
                  ),
                  _tile(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'Заказы',
                    index: 2,
                  ),
                  const Divider(height: 24),
                  _tile(
                    context,
                    icon: Icons.bar_chart_outlined,
                    title: 'Отчеты',
                    index: 3,
                  ),
                  _tile(
                    context,
                    icon: Icons.info_outline,
                    title: 'Справка',
                    index: 4,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Программный модуль',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = selectedIndex == index;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
      onTap: () {
        onSelected(index);
        Navigator.pop(context);
      },
    );
  }
}