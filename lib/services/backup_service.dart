import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../database/db_service.dart';

class BackupService {
  const BackupService();

  Future<String> _getDatabasesPath() async {
    final db = DbService.instance.database;
    final path = db.path;
    return p.dirname(path);
  }

  Future<String> createBackup() async {
    final dbPath = await _getDatabasesPath();
    final sourcePath = p.join(dbPath, 'restaurant.db');

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final backupPath = p.join(dbPath, 'CibusSanus_backup_$timestamp.db');

    await File(sourcePath).copy(backupPath);
    return backupPath;
  }

  Future<String> restoreBackup(String backupPath) async {
    final dbPath = await _getDatabasesPath();
    final targetPath = p.join(dbPath, 'restaurant.db');

    await DbService.instance.close();
    await File(backupPath).copy(targetPath);
    await DbService.instance.init();

    return targetPath;
  }

  Future<List<FileSystemEntity>> getBackups() async {
    final dbPath = await _getDatabasesPath();
    final dir = Directory(dbPath);
    final files = dir.listSync().where((f) =>
      f.path.contains('CibusSanus_backup_') && f.path.endsWith('.db')
    ).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> exportFullData() async {
    final db = DbService.instance.database;
    final tables = ['categories', 'dishes', 'orders', 'order_items', 'waiters',
      'restaurant_tables', 'reservations', 'tips', 'shifts', 'expenses',
      'discounts', 'customers', 'cash_registers', 'inventory', 'waiter_schedules', 'split_payments'];

    final buffer = StringBuffer();
    buffer.writeln('-- CibusSanus Полный экспорт данных');
    buffer.writeln('-- Дата: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    for (final table in tables) {
      try {
        final rows = await db.query(table);
        if (rows.isEmpty) continue;
        buffer.writeln('-- Table: $table');
        buffer.writeln('DELETE FROM $table;');
        for (final row in rows) {
          final columns = row.keys.join(', ');
          final values = row.values.map((v) {
            if (v == null) return 'NULL';
            if (v is String) return "'${v.replaceAll("'", "''")}'";
            return v.toString();
          }).join(', ');
          buffer.writeln('INSERT INTO $table ($columns) VALUES ($values);');
        }
        buffer.writeln();
      } catch (e) {
        print('Backup table $table error: $e');
      }
    }

    final dbPath = await _getDatabasesPath();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final path = p.join(dbPath, 'CibusSanus_export_$timestamp.sql');
    await File(path).writeAsString(buffer.toString());
    return path;
  }
}
