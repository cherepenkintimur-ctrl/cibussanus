import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/category.dart';
import '../models/dish.dart';
import '../models/order.dart';

class ExcelExportService {
  const ExcelExportService();

  Future<String> _savePath(String defaultName) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, defaultName);
  }

  Future<String> exportCategories(List<Category> categories) async {
    final path = await _savePath('categories.xlsx');

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Категории');
    final sheet = excel['Категории'];

    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Название'),
      TextCellValue('Описание'),
      TextCellValue('Дата создания'),
    ]);

    for (final c in categories) {
      sheet.appendRow([
        IntCellValue(c.id ?? 0),
        TextCellValue(c.name),
        TextCellValue(c.description ?? ''),
        TextCellValue(c.createdAt?.toString() ?? ''),
      ]);
    }

    _autoWidth(sheet, 4);
    final bytes = excel.save();
    if (bytes != null) {
      await File(path).writeAsBytes(bytes);
    }
    return path;
  }

  Future<String> exportDishes(List<Dish> dishes, String Function(int?) getCategoryName) async {
    final path = await _savePath('dishes.xlsx');

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Блюда');
    final sheet = excel['Блюда'];

    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Категория'),
      TextCellValue('Название'),
      TextCellValue('Цена'),
      TextCellValue('Описание'),
      TextCellValue('Активно'),
    ]);

    for (final d in dishes) {
      sheet.appendRow([
        IntCellValue(d.id ?? 0),
        TextCellValue(getCategoryName(d.categoryId)),
        TextCellValue(d.name),
        DoubleCellValue(d.price),
        TextCellValue(d.description ?? ''),
        TextCellValue(d.isActive ? 'Да' : 'Нет'),
      ]);
    }

    _autoWidth(sheet, 6);
    final bytes = excel.save();
    if (bytes != null) {
      await File(path).writeAsBytes(bytes);
    }
    return path;
  }

  Future<String> exportOrders(
    List<OrderModel> orders,
    List<Map<String, dynamic>> Function(int orderId) getDetails,
  ) async {
    final path = await _savePath('orders.xlsx');

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Заказы');
    final sheet = excel['Заказы'];

    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Номер заказа'),
      TextCellValue('Дата'),
      TextCellValue('Способ оплаты'),
      TextCellValue('Сумма'),
      TextCellValue('Комментарий'),
      TextCellValue('Состав заказа'),
    ]);

    for (final o in orders) {
      final details = getDetails(o.id ?? 0);
      final itemsStr = details
          .map((d) => '${d['dish_name']} x${d['quantity']} = ${d['line_total']} ₽')
          .join('; ');

      sheet.appendRow([
        IntCellValue(o.id ?? 0),
        TextCellValue(o.orderNumber),
        TextCellValue(o.orderDate?.toString() ?? ''),
        TextCellValue(o.paymentMethod ?? ''),
        DoubleCellValue(o.totalAmount),
        TextCellValue(o.notes ?? ''),
        TextCellValue(itemsStr),
      ]);
    }

    _autoWidth(sheet, 7);
    final bytes = excel.save();
    if (bytes != null) {
      await File(path).writeAsBytes(bytes);
    }
    return path;
  }

  Future<String> exportReport({
    required DateTime startDate,
    required DateTime endDate,
    required dynamic revenue,
    required dynamic averageCheck,
    required dynamic maximumCheck,
    required dynamic minimumCheck,
    required List<Map<String, dynamic>> hourlyLoad,
    required List<Map<String, dynamic>> topDishes,
  }) async {
    final path = await _savePath('report_${startDate.day}_${startDate.month}_${startDate.year}.xlsx');

    final excel = Excel.createExcel();

    final summary = excel['Сводка'];
    summary.appendRow([TextCellValue('Отчёт за период')]);
    summary.appendRow([
      TextCellValue('Период'),
      TextCellValue('${startDate.day}.${startDate.month}.${startDate.year} — ${endDate.day}.${endDate.month}.${endDate.year}'),
    ]);
    summary.appendRow([]);
    summary.appendRow([TextCellValue('Показатель'), TextCellValue('Значение')]);
    summary.appendRow([TextCellValue('Выручка'), TextCellValue('${_toDouble(revenue).toStringAsFixed(2)} ₽')]);
    summary.appendRow([TextCellValue('Средний чек'), TextCellValue('${_toDouble(averageCheck).toStringAsFixed(2)} ₽')]);
    summary.appendRow([TextCellValue('Максимальный чек'), TextCellValue('${_toDouble(maximumCheck).toStringAsFixed(2)} ₽')]);
    summary.appendRow([TextCellValue('Минимальный чек'), TextCellValue('${_toDouble(minimumCheck).toStringAsFixed(2)} ₽')]);
    _autoWidth(summary, 2);

    final hourly = excel['По часам'];
    hourly.appendRow([
      TextCellValue('Час'),
      TextCellValue('Количество заказов'),
      TextCellValue('Выручка'),
    ]);
    for (final row in hourlyLoad) {
      final hour = row['hour'] ?? 0;
      final count = _toInt(row['orders_count']);
      final rev = _toDouble(row['revenue']);
      hourly.appendRow([
        TextCellValue('$hour:00'),
        IntCellValue(count),
        DoubleCellValue(rev),
      ]);
    }
    _autoWidth(hourly, 3);

    final top = excel['ТОП блюд'];
    top.appendRow([
      TextCellValue('№'),
      TextCellValue('Блюдо'),
      TextCellValue('Продано (шт.)'),
      TextCellValue('Выручка'),
    ]);
    int rank = 1;
    for (final dish in topDishes) {
      final qty = _toInt(dish['quantity_sold']);
      final rev = _toDouble(dish['revenue']);
      top.appendRow([
        IntCellValue(rank++),
        TextCellValue(dish['dish_name'].toString()),
        IntCellValue(qty),
        DoubleCellValue(rev),
      ]);
    }
    _autoWidth(top, 4);

    excel.delete('Sheet1');

    final bytes = excel.save();
    if (bytes != null) {
      await File(path).writeAsBytes(bytes);
    }
    return path;
  }

  void _autoWidth(Sheet sheet, int colCount) {
    for (var col = 0; col < colCount; col++) {
      var maxLen = 0;
      for (final row in sheet.rows) {
        if (col < row.length) {
          final val = row[col]?.value;
          final len = val?.toString().length ?? 0;
          if (len > maxLen) maxLen = len;
        }
      }
      sheet.setColumnWidth(col, (maxLen + 4).toDouble());
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
