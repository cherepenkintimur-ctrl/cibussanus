import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionCard(
              context,
              title: 'Назначение программы',
              icon: Icons.info_outline,
              child: const Text(
                'Программный модуль CibusSanus предназначен для учета продаж ресторана европейской кухни. '
                'Приложение позволяет вести справочник категорий и блюд, оформлять и редактировать заказы, '
                'а также формировать отчеты по выручке, среднему чеку и загруженности по часам.',
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'Инструкция по использованию',
              icon: Icons.menu_book_outlined,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Откройте раздел «Категории» и добавьте категории блюд.'),
                  SizedBox(height: 8),
                  Text('2. В разделе «Блюда» заполните меню, цену, описание и активность.'),
                  SizedBox(height: 8),
                  Text('3. В разделе «Заказы» создайте заказ, выберите блюда и количество.'),
                  SizedBox(height: 8),
                  Text('4. В разделе «Отчеты» выберите период и сформируйте отчет.'),
                  SizedBox(height: 8),
                  Text('5. Используйте поиск, редактирование и удаление записей при необходимости.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'О разработчике',
              icon: Icons.person_outline,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ФИО: Черепенькин Тимур Антонович'),
                  SizedBox(height: 6),
                  Text('Группа: Информационные системы и программирование 943'),
                  SizedBox(height: 6),
                  Text('Год разработки: 2026'),
                  SizedBox(height: 6),
                  Text('Проект: программный модуль учета продаж ресторана европейской кухни CibusSanus'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}