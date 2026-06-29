import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/db_service.dart';
import '../../main.dart';
import '../../services/backup_service.dart';
import '../../widgets/export_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Restaurant Profile
  final _nameController = TextEditingController(text: 'CibusSanus');
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Appearance
  bool _darkMode = false;
  bool _useSystemTheme = true;

  // Business Settings
  String _currency = '₽';
  final _taxRateController = TextEditingController(text: '20');
  final _autoCloseController = TextEditingController(text: '24');

  // Notifications
  bool _kitchenAlerts = true;
  bool _reservationReminders = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('restaurant_name') ?? 'CibusSanus';
      _addressController.text = prefs.getString('restaurant_address') ?? '';
      _phoneController.text = prefs.getString('restaurant_phone') ?? '';
      _emailController.text = prefs.getString('restaurant_email') ?? '';

      _useSystemTheme = prefs.getBool('use_system_theme') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;

      _currency = prefs.getString('currency') ?? '₽';
      _taxRateController.text = prefs.getString('tax_rate') ?? '20';
      _autoCloseController.text = prefs.getString('auto_close_hours') ?? '24';

      _kitchenAlerts = prefs.getBool('kitchen_alerts') ?? true;
      _reservationReminders = prefs.getBool('reservation_reminders') ?? true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _backupDatabase() async {
    try {
      final path = await const BackupService().createBackup();
      _showSnackBar('Бэкап создан: $path');
    } catch (e) {
      _showSnackBar('Ошибка: $e');
    }
  }

  Future<void> _restoreDatabase() async {
    try {
      final backups = await const BackupService().getBackups();
      if (backups.isEmpty) {
        _showSnackBar('Нет доступных бэкапов');
        return;
      }

      final selected = await showDialog<FileSystemEntity>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Восстановление'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (_, i) {
                final f = backups[i];
                final name = f.path.split('\\').last.split('/').last;
                return ListTile(
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  onTap: () => Navigator.pop(ctx, f),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ],
        ),
      );

      if (selected == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Подтверждение'),
          content: const Text('Восстановить базу данных из выбранного бэкапа? Текущие данные будут заменены.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Восстановить')),
          ],
        ),
      );

      if (confirmed == true) {
        await const BackupService().restoreBackup(selected.path);
        if (mounted) _showSnackBar('База данных восстановлена');
      }
    } catch (e) {
      _showSnackBar('Ошибка: $e');
    }
  }

  Future<void> _clearAllData() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистка данных'),
        content: const Text('Вы уверены? Это действие необратимо.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Далее')),
        ],
      ),
    );
    if (first != true) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Вы действительно хотите удалить ВСЕ данные?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (second == true) {
      try {
        final db = DbService.instance.database;
        await db.delete('split_payments');
        await db.delete('order_items');
        await db.delete('tips');
        await db.delete('orders');
        await db.delete('waiter_schedules');
        await db.delete('shifts');
        await db.delete('reservations');
        await db.delete('cash_registers');
        await db.delete('inventory');
        await db.delete('expenses');
        await db.delete('discounts');
        await db.delete('customers');
        await db.delete('dishes');
        await db.delete('categories');
        await db.delete('waiters');
        await db.delete('restaurant_tables');
        await db.execute('DELETE FROM sqlite_sequence');
        if (mounted) _showSnackBar('Все данные удалены');
      } catch (e) {
        _showSnackBar('Ошибка: $e');
      }
    }
  }

  Future<void> _exportToExcel() async {
    final db = DbService.instance.database;
    await showExportDialog(
      context,
      title: 'Экспорт данных',
      actions: [
        ExportAction(
          label: 'Экспорт в Excel',
          icon: Icons.table_chart,
          extension: 'xlsx',
          generateData: () async {
            final tables = ['categories', 'dishes', 'orders', 'order_items', 'waiters',
              'restaurant_tables', 'reservations', 'tips', 'shifts', 'expenses',
              'discounts', 'customers', 'cash_registers', 'inventory', 'waiter_schedules', 'split_payments'];
            final buf = StringBuffer();
            for (final table in tables) {
              final rows = await db.query(table);
              if (rows.isEmpty) continue;
              buf.writeln('=== $table ===');
              if (rows.isNotEmpty) {
                buf.writeln(rows.first.keys.join('\t'));
                for (final row in rows) {
                  buf.writeln(row.values.join('\t'));
                }
              }
              buf.writeln();
            }
            return Uint8List.fromList(buf.toString().codeUnits);
          },
        ),
        ExportAction(
          label: 'Экспорт в SQL',
          icon: Icons.code,
          extension: 'sql',
          generateData: () async {
            final content = await const BackupService().exportFullData();
            return Uint8List.fromList(content.codeUnits);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxRateController.dispose();
    _autoCloseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Профиль ресторана'),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Название ресторана'),
            onChanged: (v) => _saveSetting('restaurant_name', v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Адрес'),
            onChanged: (v) => _saveSetting('restaurant_address', v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Телефон'),
            keyboardType: TextInputType.phone,
            onChanged: (v) => _saveSetting('restaurant_phone', v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Эл. почта'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => _saveSetting('restaurant_email', v),
          ),
          const Divider(height: 40),

          _buildSectionHeader('Оформление'),
          SwitchListTile(
            title: const Text('Тёмная тема'),
            subtitle: const Text('Включить тёмный режим'),
            value: _darkMode,
            onChanged: (value) {
              setState(() => _darkMode = value);
              _saveSetting('dark_mode', value);
              themeNotifier.setDarkMode(value);
            },
          ),
          SwitchListTile(
            title: const Text('Системная тема'),
            subtitle: const Text('Использовать тему системы'),
            value: _useSystemTheme,
            onChanged: (value) {
              setState(() => _useSystemTheme = value);
              _saveSetting('use_system_theme', value);
              themeNotifier.setSystemTheme(value);
            },
          ),
          const Divider(height: 40),

          _buildSectionHeader('Бизнес-настройки'),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(labelText: 'Валюта по умолчанию'),
            items: const [
              DropdownMenuItem(value: '₽', child: Text('₽ рубль')),
              DropdownMenuItem(value: '\$', child: Text('\$ доллар')),
              DropdownMenuItem(value: '€', child: Text('€ евро')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _currency = value);
                _saveSetting('currency', value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taxRateController,
            decoration: const InputDecoration(labelText: 'Ставка налога (%)', suffixText: '%'),
            keyboardType: TextInputType.number,
            onChanged: (v) => _saveSetting('tax_rate', v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _autoCloseController,
            decoration: const InputDecoration(labelText: 'Авто-закрытие заказов (часов)'),
            keyboardType: TextInputType.number,
            onChanged: (v) => _saveSetting('auto_close_hours', v),
          ),
          const Divider(height: 40),

          _buildSectionHeader('Уведомления'),
          SwitchListTile(
            title: const Text('Оповещения кухни'),
            value: _kitchenAlerts,
            onChanged: (value) {
              setState(() => _kitchenAlerts = value);
              _saveSetting('kitchen_alerts', value);
            },
          ),
          SwitchListTile(
            title: const Text('Напоминания о бронированиях'),
            value: _reservationReminders,
            onChanged: (value) {
              setState(() => _reservationReminders = value);
              _saveSetting('reservation_reminders', value);
            },
          ),
          const Divider(height: 40),

          _buildSectionHeader('Управление данными'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Бэкап базы данных'),
            onTap: _backupDatabase,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Восстановить базу данных'),
            onTap: _restoreDatabase,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Экспорт в Excel'),
            onTap: _exportToExcel,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Очистить все данные', style: TextStyle(color: Colors.red)),
            onTap: _clearAllData,
          ),
          const Divider(height: 40),

          _buildSectionHeader('О приложении'),
          const ListTile(
            leading: Icon(Icons.restaurant),
            title: Text('CibusSanus'),
            subtitle: Text('Версия 2.0.0 — Учёт продаж ресторана'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Разработчик'),
            subtitle: Text('Черепенькин Тимур Антонович'),
          ),
          const ListTile(
            leading: Icon(Icons.phone),
            title: Text('Телефон'),
            subtitle: Text('+7 (995) 062-76-12'),
          ),
          const ListTile(
            leading: Icon(Icons.email),
            title: Text('Почта'),
            subtitle: Text('cherepenkintimur@gmail.com'),
          ),
          const ListTile(
            leading: Icon(Icons.school),
            title: Text('Группа'),
            subtitle: Text('Информационные системы и программирование 943'),
          ),
          const ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text('Год'),
            subtitle: Text('2026'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
