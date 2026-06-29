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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF231013) : const Color(0xFF6B1520),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E6D0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restaurant, size: 36, color: Color(0xFFD4A574)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CibusSanus',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF5E6D0),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Europaeische Kueche',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFFD4A574).withValues(alpha: 0.9),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _sectionHeader(context, 'Главное'),
                  _tile(context, icon: Icons.dashboard_rounded, title: 'Панель управления', index: 0),
                  _tile(context, icon: Icons.edit_note, title: 'Управление данными', index: 1),
                  _tile(context, icon: Icons.kitchen, title: 'Кухня', index: 5),
                  _tile(context, icon: Icons.search, title: 'Поиск', index: 20),
                  const Divider(height: 16),
                  _sectionHeader(context, 'Меню'),
                  _tile(context, icon: Icons.category_outlined, title: 'Категории', index: 2),
                  _tile(context, icon: Icons.restaurant_menu_outlined, title: 'Блюда', index: 3),
                  const Divider(height: 16),
                  _sectionHeader(context, 'Операции'),
                  _tile(context, icon: Icons.receipt_long_outlined, title: 'Заказы', index: 4),
                  _tile(context, icon: Icons.people_outline, title: 'Официанты', index: 6),
                  _tile(context, icon: Icons.table_restaurant_outlined, title: 'Столики и бронь', index: 7),
                  _tile(context, icon: Icons.calendar_month, title: 'Календарь броней', index: 19),
                  const Divider(height: 16),
                  _sectionHeader(context, 'Финансы'),
                  _tile(context, icon: Icons.attach_money, title: 'Чаевые', index: 8),
                  _tile(context, icon: Icons.schedule, title: 'Смены', index: 9),
                  _tile(context, icon: Icons.account_balance_wallet_outlined, title: 'Расходы', index: 10),
                  _tile(context, icon: Icons.local_offer_outlined, title: 'Скидки', index: 11),
                  _tile(context, icon: Icons.point_of_sale, title: 'Касса / Z-отчёт', index: 16),
                  const Divider(height: 16),
                  _sectionHeader(context, 'Управление'),
                  _tile(context, icon: Icons.person_add, title: 'Клиенты', index: 15),
                  _tile(context, icon: Icons.inventory_2, title: 'Склад', index: 17),
                  _tile(context, icon: Icons.view_week, title: 'График смен', index: 18),
                  const Divider(height: 16),
                  _sectionHeader(context, 'Аналитика'),
                  _tile(context, icon: Icons.bar_chart_outlined, title: 'Базовые отчёты', index: 12),
                  _tile(context, icon: Icons.account_balance_rounded, title: 'Выручка и прибыль', index: 13),
                  _tile(context, icon: Icons.analytics_outlined, title: 'Продвинутая аналитика', index: 14),
                  const Divider(height: 16),
                  _tile(context, icon: Icons.settings, title: 'Настройки', index: 21),
                  _tile(context, icon: Icons.info_outline, title: 'Справка', index: 22),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'CibusSanus v2.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isDark ? const Color(0xFFC9A96E) : const Color(0xFF6B1520),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isSelected
            ? (isDark ? const Color(0xFFC9A96E) : const Color(0xFF6B1520))
            : (isDark ? const Color(0xFFF5E6D0) : const Color(0xFF6B1520)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? (isDark ? const Color(0xFFC9A96E) : const Color(0xFF6B1520))
              : (isDark ? const Color(0xFFF5E6D0) : const Color(0xFF3D1A1E)),
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      selectedTileColor: isSelected
          ? (isDark
              ? const Color(0xFF3D1A1E).withValues(alpha: 0.5)
              : const Color(0xFFE8D5C4).withValues(alpha: 0.3))
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
      onTap: () {
        onSelected(index);
        Navigator.pop(context);
      },
    );
  }
}
