import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/converters.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/waiter_repository.dart';
import '../../repositories/table_repository.dart';
import '../../repositories/customer_repository.dart';
import 'package:intl/intl.dart';

class ReceiptViewScreen extends StatelessWidget {
  final OrderModel order;
  const ReceiptViewScreen({super.key, required this.order});

  static const double _receiptWidth = 320;
  static const String _doubleLine = '═══════════════════════════════';
  static const String _singleLine = '───────────────────────────────';

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year  $hour:$minute';
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0);
    return '$formatted₽';
  }

  Future<_ReceiptData> _loadData() async {
    final items = await const OrderRepository().getDetails(order.id!);
    String? waiterName;
    String? tableNumber;

    if (order.waiterId != null) {
      final waiter = await const WaiterRepository().getById(order.waiterId!);
      waiterName = waiter?.name;
    }

    if (order.tableId != null) {
      final table = await const TableRepository().getById(order.tableId!);
      tableNumber = table?.tableNumber.toString();
    }

    return _ReceiptData(
      items: items,
      waiterName: waiterName ?? '—',
      tableNumber: tableNumber ?? '—',
    );
  }

  Widget _buildReceiptText(String text, {bool bold = false, bool centered = false}) {
    return Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.left,
      style: TextStyle(
        fontFamily: 'Courier New',
        fontSize: 14,
        height: 1.3,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildReceiptLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _buildReceiptText(text),
    );
  }

  Widget _buildReceiptLineBold(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _buildReceiptText(text, bold: true),
    );
  }

  Widget _buildReceiptCenter(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _buildReceiptText(text, centered: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чек'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Скопировать',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скопировано в буфер обмена')),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<_ReceiptData>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Ошибка загрузки данных: ${snapshot.error}'),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final dateStr = order.orderDate != null ? _formatDate(order.orderDate!) : '—';
          final subtotal = order.totalAmount;
          final discount = order.discountAmount;
          final finalAmount = order.finalAmount;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                children: [
                  Container(
                    width: _receiptWidth,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildReceiptCenter(_doubleLine),
                        const SizedBox(height: 4),
                        _buildReceiptCenter('CIBUSSANUS'),
                        _buildReceiptCenter('Европейская кухня'),
                        const SizedBox(height: 4),
                        _buildReceiptCenter(_doubleLine),
                        const SizedBox(height: 8),
                        _buildReceiptLine('Чек: ${order.orderNumber}'),
                        _buildReceiptLine('Дата: $dateStr'),
                        _buildReceiptLine('Официант: ${data.waiterName}'),
                        _buildReceiptLine('Столик: №${data.tableNumber}'),
                        const SizedBox(height: 8),
                        _buildReceiptLine(_singleLine),
                        const SizedBox(height: 4),
                        _buildReceiptLineBold('СОСТАВ:'),
                        const SizedBox(height: 4),
                        for (final item in data.items)
                          _buildReceiptLine(
                            '  ${item['quantity']}x ${(item['dish_name'] ?? '').toString().padRight(18)}${_formatCurrency(parseDouble(item['line_total']))}',
                          ),
                        const SizedBox(height: 8),
                        _buildReceiptLine(_singleLine),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildReceiptLineBold('ПОДЫТОГ:'),
                            _buildReceiptLineBold(_formatCurrency(subtotal)),
                          ],
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildReceiptLine('СКИДКА:'),
                              _buildReceiptLine('-${_formatCurrency(discount)}'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildReceiptLine(_singleLine),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildReceiptLineBold('ИТОГО К ОПЛАТЕ:'),
                            _buildReceiptLineBold(_formatCurrency(finalAmount)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildReceiptLine(_singleLine),
                        const SizedBox(height: 4),
                        _buildReceiptLine('Оплата: ${order.paymentMethod ?? '—'}'),
                        if (order.notes != null && order.notes!.isNotEmpty)
                          _buildReceiptLine('Комментарий: ${order.notes}'),
                        const SizedBox(height: 8),
                        _buildReceiptLine(_singleLine),
                        const SizedBox(height: 8),
                        _buildReceiptCenter('Спасибо за визит!'),
                        _buildReceiptCenter('Ждём вас снова!'),
                        const SizedBox(height: 4),
                        _buildReceiptCenter(_doubleLine),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Скопировано в буфер обмена')),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Скопировать'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Поделиться чеком')),
                              );
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Поделиться'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReceiptData {
  final List<Map<String, dynamic>> items;
  final String waiterName;
  final String tableNumber;

  const _ReceiptData({
    required this.items,
    required this.waiterName,
    required this.tableNumber,
  });
}
