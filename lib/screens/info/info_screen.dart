import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionCard(
              context,
              title: 'Назначение программы',
              icon: Icons.info_outline,
              child: const Text(
                'Программный модуль CibusSanus предназначен для комплексного учета продаж ресторана европейской кухни. '
                'Приложение позволяет вести справочник категорий и блюд с ценами и себестоимостью, '
                'оформлять и редактировать заказы, управлять столиками и бронированиями, '
                'учитывать чаевые, расходы, смены и график работы персонала, '
                'а также формировать отчёты по выручке, прибыли, аналитике и Z-отчётам.',
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'Разделы приложения',
              icon: Icons.dashboard_outlined,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Панель управления — общая статистика, выручка, топ блюд, тренды.'),
                  SizedBox(height: 6),
                  Text('Управление данными — быстрый доступ к блюдам, категориям, персоналу и расходам.'),
                  SizedBox(height: 6),
                  Text('Заказы — создание, редактирование и отслеживание заказов по столикам.'),
                  SizedBox(height: 6),
                  Text('Кухня — экран кухни с очередью текущих заказов.'),
                  SizedBox(height: 6),
                  Text('Столики и бронь — управление зонами, столиками и бронированиями.'),
                  SizedBox(height: 6),
                  Text('Чаевые — статистика и рейтинг официантов по чаевым.'),
                  SizedBox(height: 6),
                  Text('Смены — управление сменами и рабочим графиком.'),
                  SizedBox(height: 6),
                  Text('Расходы — учёт расходов ресторана по категориям.'),
                  SizedBox(height: 6),
                  Text('Касса — открытие/закрытие кассы, Z-отчёты.'),
                  SizedBox(height: 6),
                  Text('Аналитика — матрица BCG, прогнозы, сравнения периодов.'),
                  SizedBox(height: 6),
                  Text('Отчёты — выручка, прибыль, загрузка по часам.'),
                  SizedBox(height: 6),
                  Text('Склад — учёт ингредиентов и запасов.'),
                  SizedBox(height: 6),
                  Text('График смен — посменное расписание официантов.'),
                ],
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
                  Text('1. Откройте «Управление данными» → «Категории» и добавьте категории блюд.'),
                  SizedBox(height: 6),
                  Text('2. В «Блюда» добавьте блюда с ценой, себестоимостью, объёмом и весом.'),
                  SizedBox(height: 6),
                  Text('3. В «Официанты» добавьте персонал с ролями и окладами.'),
                  SizedBox(height: 6),
                  Text('4. В «Заказы» создайте заказ: выберите столик, официанта и блюда.'),
                  SizedBox(height: 6),
                  Text('5. На «Кухне» отслеживайте статусы приготовления.'),
                  SizedBox(height: 6),
                  Text('6. В «Кассе» откройте кассу перед началом смены и закройте по итогам.'),
                  SizedBox(height: 6),
                  Text('7. В «Отчётах» и «Аналитике» анализируйте выручку, прибыль и тренды.'),
                  SizedBox(height: 6),
                  Text('8. В «Столиках» управляйте зонами и бронированиями.'),
                  SizedBox(height: 6),
                  Text('9. Используйте «Поиск» для быстрого нахождения заказов, блюд и клиентов.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'Клавиши быстрого доступа',
              icon: Icons.keyboard_outlined,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Иконка поиска в AppBar — быстрый переход к поиску.'),
                  SizedBox(height: 6),
                  Text('• Иконка настроек в AppBar — переход к настройкам.'),
                  SizedBox(height: 6),
                  Text('• Боковое меню — навигация по всем разделам.'),
                  SizedBox(height: 6),
                  Text('• Свайп вниз — обновление данных на текущем экране.'),
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
                  SizedBox(height: 4),
                  Text('Телефон: +7 (995) 062-76-12'),
                  SizedBox(height: 4),
                  Text('Почта: cherepenkintimur@gmail.com'),
                  SizedBox(height: 4),
                  Text('Группа: Информационные системы и программирование 943'),
                  SizedBox(height: 4),
                  Text('Год разработки: 2026'),
                  SizedBox(height: 4),
                  Text('Проект: программный модуль учёта продаж ресторана европейской кухни CibusSanus'),
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
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}