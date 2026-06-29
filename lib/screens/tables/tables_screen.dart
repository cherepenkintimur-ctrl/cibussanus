import 'package:flutter/material.dart';
import '../../database/db_service.dart';
import '../../models/converters.dart';
import '../../models/restaurant_table.dart';
import '../../models/reservation.dart';
import '../../repositories/table_repository.dart';
import '../../repositories/reservation_repository.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  final TableRepository _tableRepo = const TableRepository();
  final ReservationRepository _reservationRepo = const ReservationRepository();

  List<RestaurantTable> _tables = [];
  List<Reservation> _reservations = [];
  List<String> _zones = [];
  Map<String, dynamic> _tableStats = {};
  Map<String, dynamic> _reservationStats = {};
  String _selectedZone = 'Все';
  bool _showReservations = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tables = await _tableRepo.getAll();
    final zones = await _tableRepo.getZones();
    final stats = await _tableRepo.getTablesStats();
    final reservations = await _reservationRepo.getUpcoming();
    final resStats = await _reservationRepo.getReservationStats();
    setState(() {
      _tables = tables;
      _zones = zones;
      _tableStats = stats;
      _reservations = reservations;
      _reservationStats = resStats;
    });
  }

  List<RestaurantTable> _getFilteredTables() {
    if (_selectedZone == 'Все') {
      return _tables;
    }
    return _tables.where((t) => t.zone == _selectedZone).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Свободен':
        return Colors.green;
      case 'Занят':
        return Colors.red;
      case 'Забронирован':
        return Colors.yellow.shade700;
      case 'Резерв':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusDarkColor(String status) {
    switch (status) {
      case 'Свободен':
        return const Color(0xFF1B5E20);
      case 'Занят':
        return const Color(0xFFB71C1C);
      case 'Забронирован':
        return const Color(0xFFF57F17);
      case 'Резерв':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF424242);
    }
  }

  String _getStatusEmoji(String status) {
    switch (status) {
      case 'Свободен':
        return '🟢';
      case 'Занят':
        return '🔴';
      case 'Забронирован':
        return '🟡';
      case 'Резерв':
        return '🟠';
      default:
        return '⚪';
    }
  }

  Color _getReservationStatusColor(String status) {
    switch (status) {
      case 'Подтверждено':
        return Colors.blue;
      case 'Выполнено':
        return Colors.green;
      case 'Отменено':
        return Colors.red;
      case 'Неявка':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showCreateTableDialog() {
    final numberController = TextEditingController();
    final capacityController = TextEditingController();
    String selectedZone = _zones.isNotEmpty ? _zones.first : 'Основной зал';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый стол'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: 'Номер стола',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(
                labelText: 'Количество мест',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedZone,
              decoration: const InputDecoration(
                labelText: 'Зона',
                border: OutlineInputBorder(),
              ),
              items: _zones.map((zone) {
                return DropdownMenuItem(value: zone, child: Text(zone));
              }).toList(),
              onChanged: (value) {
                if (value != null) selectedZone = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final number = int.tryParse(numberController.text);
              final capacity = int.tryParse(capacityController.text);
              if (number != null && capacity != null) {
                final newTable = RestaurantTable(
                  id: DateTime.now().millisecondsSinceEpoch,
                  tableNumber: number,
                  capacity: capacity,
                  zone: selectedZone,
                  status: 'Свободен',
                );
                await _tableRepo.create(newTable);
                await _loadData();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showEditTableDialog(RestaurantTable table) {
    final numberController = TextEditingController(text: table.tableNumber.toString());
    final capacityController = TextEditingController(text: table.capacity.toString());
    String selectedZone = table.zone;
    String selectedStatus = table.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать стол'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: 'Номер стола',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(
                labelText: 'Количество мест',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedZone,
              decoration: const InputDecoration(
                labelText: 'Зона',
                border: OutlineInputBorder(),
              ),
              items: _zones.map((zone) {
                return DropdownMenuItem(value: zone, child: Text(zone));
              }).toList(),
              onChanged: (value) {
                if (value != null) selectedZone = value;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Статус',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Свободен', child: Text('🟢 Свободен')),
                DropdownMenuItem(value: 'Занят', child: Text('🔴 Занят')),
                DropdownMenuItem(value: 'Забронирован', child: Text('🟡 Забронирован')),
                DropdownMenuItem(value: 'Резерв', child: Text('🟠 Резерв')),
              ],
              onChanged: (value) {
                if (value != null) selectedStatus = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final number = int.tryParse(numberController.text);
              final capacity = int.tryParse(capacityController.text);
              if (number != null && capacity != null) {
                final updatedTable = RestaurantTable(
                  id: table.id,
                  tableNumber: number,
                  capacity: capacity,
                  zone: selectedZone,
                  status: selectedStatus,
                );
                await _tableRepo.update(updatedTable);
                await _loadData();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTableDialog(RestaurantTable table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить стол'),
        content: Text('Вы уверены, что хотите удалить стол №${table.tableNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _tableRepo.delete(table.id!);
              await _loadData();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showTableDetail(RestaurantTable table) async {
    final recentOrders = await DbService.instance.query(
      'SELECT o.order_number, o.order_date, o.total_amount, o.status, w.name as waiter_name '
      'FROM orders o '
      'LEFT JOIN waiters w ON w.id = o.waiter_id '
      'WHERE o.table_id = ? '
      'ORDER BY o.order_date DESC '
      'LIMIT 5',
      arguments: [table.id],
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getStatusColor(table.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Стол №${table.tableNumber}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(table.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      table.status,
                      style: TextStyle(
                        color: _getStatusDarkColor(table.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.location_on, 'Зона', table.zone),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.people, 'Вместимость', '${table.capacity} мест'),
              if (recentOrders.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Последние заказы за столом',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 8),
                ...recentOrders.map((o) {
                  final orderDate = parseDateTime(o['order_date']);
                  final dateStr = orderDate != null
                      ? '${orderDate.day.toString().padLeft(2, '0')}.${orderDate.month.toString().padLeft(2, '0')}.${orderDate.year} '
                        '${orderDate.hour.toString().padLeft(2, '0')}:${orderDate.minute.toString().padLeft(2, '0')}'
                      : '';
                  final waiter = o['waiter_name']?.toString() ?? '—';
                  final status = o['status']?.toString() ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${o['order_number']}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Официант: $waiter',
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${parseDouble(o['total_amount']).toStringAsFixed(0)} ₽',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _tableOrderStatusColor(status).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _tableOrderStatusColor(status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showChangeStatusDialog(table);
                      },
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Статус'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditTableDialog(table);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Редактировать'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteTableDialog(table);
                      },
                      icon: const Icon(Icons.delete, size: 18),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      label: const Text('Удалить'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Color _tableOrderStatusColor(String status) {
    switch (status) {
      case 'Новый':
        return Colors.blue;
      case 'Готовится':
        return Colors.orange;
      case 'Подан':
        return Colors.green;
      case 'Готово':
        return Colors.teal;
      case 'Оплачен':
        return Colors.indigo;
      case 'Отменён':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }

  void _showReservationDetail(Reservation reservation) {
    final table = _tables.firstWhere(
      (t) => t.id == reservation.tableId,
      orElse: () => const RestaurantTable(
        tableNumber: 0,
        capacity: 0,
        zone: '',
        status: '',
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getReservationStatusColor(reservation.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reservation.customerName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getReservationStatusColor(reservation.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reservation.status,
                    style: TextStyle(
                      color: _getReservationStatusColor(reservation.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.person, 'Имя', reservation.customerName),
            if (reservation.phone != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(Icons.phone, 'Телефон', reservation.phone!),
            ],
            const SizedBox(height: 8),
            _buildDetailRow(Icons.calendar_today, 'Дата и время',
                '${reservation.reservationDate.day}.${reservation.reservationDate.month}.${reservation.reservationDate.year} '
                '${reservation.reservationDate.hour.toString().padLeft(2, '0')}:${reservation.reservationDate.minute.toString().padLeft(2, '0')}'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.people, 'Гости', '${reservation.partySize} чел.'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.table_chart, 'Стол',
                table.tableNumber > 0 ? '№${table.tableNumber}' : 'Не назначен'),
            if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailRow(Icons.note, 'Заметки', reservation.notes!),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showUpdateReservationStatusDialog(reservation);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Изменить статус'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showChangeStatusDialog(RestaurantTable table) {
    String selectedStatus = table.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить статус стола №${table.tableNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('🟢 Свободен'),
              value: 'Свободен',
              groupValue: selectedStatus,
              onChanged: (value) async {
                if (value != null) {
                  selectedStatus = value;
                  final updatedTable = RestaurantTable(
                    id: table.id,
                    tableNumber: table.tableNumber,
                    capacity: table.capacity,
                    zone: table.zone,
                    status: selectedStatus,
                  );
                  await _tableRepo.update(updatedTable);
                  await _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('🔴 Занят'),
              value: 'Занят',
              groupValue: selectedStatus,
              onChanged: (value) async {
                if (value != null) {
                  selectedStatus = value;
                  final updatedTable = RestaurantTable(
                    id: table.id,
                    tableNumber: table.tableNumber,
                    capacity: table.capacity,
                    zone: table.zone,
                    status: selectedStatus,
                  );
                  await _tableRepo.update(updatedTable);
                  await _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('🟡 Забронирован'),
              value: 'Забронирован',
              groupValue: selectedStatus,
              onChanged: (value) async {
                if (value != null) {
                  selectedStatus = value;
                  final updatedTable = RestaurantTable(
                    id: table.id,
                    tableNumber: table.tableNumber,
                    capacity: table.capacity,
                    zone: table.zone,
                    status: selectedStatus,
                  );
                  await _tableRepo.update(updatedTable);
                  await _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('🟠 Резерв'),
              value: 'Резерв',
              groupValue: selectedStatus,
              onChanged: (value) async {
                if (value != null) {
                  selectedStatus = value;
                  final updatedTable = RestaurantTable(
                    id: table.id,
                    tableNumber: table.tableNumber,
                    capacity: table.capacity,
                    zone: table.zone,
                    status: selectedStatus,
                  );
                  await _tableRepo.update(updatedTable);
                  await _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showCreateReservationDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final partySizeController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    int? selectedTableId;

    final freeTables = _tables.where((t) => t.status == 'Свободен').toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новое бронирование'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя клиента',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: partySizeController,
                decoration: const InputDecoration(
                  labelText: 'Количество гостей',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Дата (ДД.ММ.ГГГГ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Время (ЧЧ:ММ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Стол',
                  border: OutlineInputBorder(),
                ),
                items: freeTables.map((table) {
                  return DropdownMenuItem(
                    value: table.id,
                    child: Text('№${table.tableNumber} (${table.capacity} мест)'),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedTableId = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final partySize = int.tryParse(partySizeController.text);
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty &&
                  partySize != null &&
                  dateController.text.isNotEmpty &&
                  timeController.text.isNotEmpty) {
                final dateParts = dateController.text.split('.');
                final timeParts = timeController.text.split(':');
                if (dateParts.length == 3 && timeParts.length == 2) {
                  final day = int.tryParse(dateParts[0]);
                  final month = int.tryParse(dateParts[1]);
                  final year = int.tryParse(dateParts[2]);
                  final hour = int.tryParse(timeParts[0]);
                  final minute = int.tryParse(timeParts[1]);
                  if (day != null && month != null && year != null && hour != null && minute != null) {
                    final reservationDate = DateTime(year, month, day, hour, minute);
                    final newReservation = Reservation(
                      customerName: nameController.text,
                      phone: phoneController.text,
                      partySize: partySize,
                      reservationDate: reservationDate,
                      tableId: selectedTableId,
                      status: 'Подтверждено',
                    );
                    await _reservationRepo.create(newReservation);
                    if (selectedTableId != null) {
                      final table = _tables.firstWhere((t) => t.id == selectedTableId);
                      await _tableRepo.update(RestaurantTable(
                        id: table.id,
                        tableNumber: table.tableNumber,
                        capacity: table.capacity,
                        zone: table.zone,
                        status: 'Забронирован',
                      ));
                    }
                    await _loadData();
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showUpdateReservationStatusDialog(Reservation reservation) {
    String selectedStatus = reservation.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Обновить статус бронирования'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Подтверждено'),
              value: 'Подтверждено',
              groupValue: selectedStatus,
              onChanged: (value) async {
                if (value != null) {
                  selectedStatus = value;
                  await _reservationRepo.update(Reservation(
                    id: reservation.id,
                    customerName: reservation.customerName,
                    phone: reservation.phone,
                    partySize: reservation.partySize,
                    reservationDate: reservation.reservationDate,
                    tableId: reservation.tableId,
                    status: selectedStatus,
                  ));
                  await _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Выполнено'),
              value: 'Выполнено',
              groupValue: selectedStatus,
              onChanged: (value) async {
                if (value != null) {
                  selectedStatus = value;
                  await _reservationRepo.update(Reservation(
                    id: reservation.id,
                    customerName: reservation.customerName,
                    phone: reservation.phone,
                    partySize: reservation.partySize,
                    reservationDate: reservation.reservationDate,
                    tableId: reservation.tableId,
                    status: selectedStatus,
                  ));
                  await _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Отменено'),
              value: 'Отменено',
              groupValue: selectedStatus,
              onChanged: (value) async {
                if (value != null) {
                  selectedStatus = value;
                  await _reservationRepo.update(Reservation(
                    id: reservation.id,
                    customerName: reservation.customerName,
                    phone: reservation.phone,
                    partySize: reservation.partySize,
                    reservationDate: reservation.reservationDate,
                    tableId: reservation.tableId,
                    status: selectedStatus,
                  ));
                  await _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Неявка'),
              value: 'Неявка',
              groupValue: selectedStatus,
              onChanged: (value) async {
                if (value != null) {
                  selectedStatus = value;
                  await _reservationRepo.update(Reservation(
                    id: reservation.id,
                    customerName: reservation.customerName,
                    phone: reservation.phone,
                    partySize: reservation.partySize,
                    reservationDate: reservation.reservationDate,
                    tableId: reservation.tableId,
                    status: selectedStatus,
                  ));
                  await _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTables = _getFilteredTables();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Столики и бронь'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showReservations ? Icons.grid_view : Icons.calendar_today),
            tooltip: _showReservations ? 'План зала' : 'Бронирования',
            onPressed: () {
              setState(() {
                _showReservations = !_showReservations;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: _showReservations ? 'Новое бронирование' : 'Новый стол',
            onPressed: _showReservations
                ? _showCreateReservationDialog
                : _showCreateTableDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  'Всего столов',
                  _tableStats['total']?.toString() ?? '0',
                  Icons.table_chart,
                  Theme.of(context).colorScheme.primary,
                ),
                _buildStatItem(
                  context,
                  'Свободно',
                  _tableStats['free']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatItem(
                  context,
                  'Занято',
                  _tableStats['occupied']?.toString() ?? '0',
                  Icons.cancel,
                  Colors.red,
                ),
                _buildStatItem(
                  context,
                  'Вместимость',
                  _tableStats['totalCapacity']?.toString() ?? '0',
                  Icons.people,
                  Colors.orange,
                ),
              ],
            ),
          ),
          if (!_showReservations) ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('Все'),
                      selected: _selectedZone == 'Все',
                      onSelected: (selected) {
                        setState(() {
                          _selectedZone = 'Все';
                        });
                      },
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  ..._zones.map((zone) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(zone),
                        selected: _selectedZone == zone,
                        onSelected: (selected) {
                          setState(() {
                            _selectedZone = zone;
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    );
                  }),
                ],
              ),
            ),
            Expanded(
              child: _selectedZone == 'Все'
                  ? ListView(
                      padding: const EdgeInsets.all(8),
                      children: _buildZoneSections(filteredTables),
                    )
                  : _buildZoneSection(
                      _selectedZone,
                      filteredTables.where((t) => t.zone == _selectedZone).toList(),
                    ),
            ),
          ] else ...[
            Expanded(
              child: _reservations.isEmpty
                  ? const Center(
                      child: Text(
                        'Нет предстоящих бронирований',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reservations.length,
                      itemBuilder: (context, index) {
                        final reservation = _reservations[index];
                        final table = _tables.firstWhere(
                          (t) => t.id == reservation.tableId,
                          orElse: () => const RestaurantTable(
                            tableNumber: 0,
                            capacity: 0,
                            zone: '',
                            status: '',
                          ),
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            onTap: () => _showReservationDetail(reservation),
                            leading: CircleAvatar(
                              backgroundColor: _getReservationStatusColor(reservation.status),
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              reservation.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('📞 ${reservation.phone ?? ''}'),
                                Text('📅 ${reservation.reservationDate}'),
                                Text('👥 ${reservation.partySize} гостей'),
                                Text('🪑 Стол №${table.tableNumber}'),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getReservationStatusColor(reservation.status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    reservation.status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () =>
                                      _showUpdateReservationStatusDialog(reservation),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  List<Widget> _buildZoneSections(List<RestaurantTable> tables) {
    final Map<String, List<RestaurantTable>> grouped = {};
    for (final table in tables) {
      grouped.putIfAbsent(table.zone, () => []).add(table);
    }

    return grouped.entries.map((entry) {
      return _buildZoneSection(entry.key, entry.value);
    }).toList();
  }

  Widget _buildZoneSection(String zone, List<RestaurantTable> tables) {
    if (tables.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                _getZoneIcon(zone),
                color: Theme.of(context).colorScheme.primary,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                zone,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tables.length} столов',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.6,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            return _buildTableCard(tables[index]);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTableCard(RestaurantTable table) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _getStatusColor(table.status),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showTableDetail(table),
        onLongPress: () => _showTableOptions(table),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(table.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_getStatusEmoji(table.status)} ${table.status}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusDarkColor(table.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '№${table.tableNumber}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    '${table.capacity} мест',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                table.zone,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getZoneIcon(String zone) {
    switch (zone) {
      case 'Основной зал':
        return Icons.restaurant;
      case 'Терраса':
        return Icons.deck;
      case 'Банкетный зал':
        return Icons.celebration;
      case 'VIP зона':
        return Icons.diamond;
      case 'У бара':
        return Icons.local_bar;
      default:
        return Icons.room;
    }
  }

  void _showTableOptions(RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(context);
                _showEditTableDialog(table);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.orange),
              title: const Text('Изменить статус'),
              onTap: () {
                Navigator.pop(context);
                _showChangeStatusDialog(table);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteTableDialog(table);
              },
            ),
          ],
        ),
      ),
    );
  }
}
