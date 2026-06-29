import 'package:flutter/material.dart';
import '../../models/reservation.dart';
import '../../models/restaurant_table.dart';

import '../../repositories/reservation_repository.dart';
import '../../repositories/table_repository.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ReservationRepository _reservationRepo = const ReservationRepository();
  final TableRepository _tableRepo = const TableRepository();

  late DateTime _currentMonth;
  late DateTime _selectedDate;
  List<Reservation> _monthReservations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = now;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reservations = await _reservationRepo.getAll();
      final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      _monthReservations = reservations.where((r) {
        return !r.reservationDate.isBefore(monthStart) &&
            !r.reservationDate.isAfter(monthEnd);
      }).toList();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadData();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month);
      _selectedDate = now;
    });
    _loadData();
  }

  List<Reservation> _getReservationsForDay(DateTime day) {
    return _monthReservations.where((r) {
      return r.reservationDate.year == day.year &&
          r.reservationDate.month == day.month &&
          r.reservationDate.day == day.day;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Подтверждено';
      case 'pending':
        return 'Ожидание';
      case 'cancelled':
        return 'Отменено';
      default:
        return status;
    }
  }

  String _monthName(int month) {
    const names = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return names[month - 1];
  }

  String _dayName(int weekday) {
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return names[weekday - 1];
  }

  Widget _buildCalendarGrid() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;
    final totalCells = ((startWeekday - 1 + daysInMonth) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(7, (index) {
              return Expanded(
                child: Center(
                  child: Text(
                    _dayName(index + 1),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: index >= 5
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          ...List.generate((totalCells / 7).ceil(), (weekIndex) {
            return Row(
              children: List.generate(7, (dayIndex) {
                final cellIndex = weekIndex * 7 + dayIndex;
                final dayNumber = cellIndex - startWeekday + 2;
                final isCurrentMonth = dayNumber >= 1 && dayNumber <= daysInMonth;

                if (!isCurrentMonth) {
                  return const Expanded(child: SizedBox(height: 48));
                }

                final day = DateTime(
                  _currentMonth.year,
                  _currentMonth.month,
                  dayNumber,
                );
                final isToday = day.year == now.year &&
                    day.month == now.month &&
                    day.day == now.day;
                final isSelected = day.year == _selectedDate.year &&
                    day.month == _selectedDate.month &&
                    day.day == _selectedDate.day;
                final dayReservations = _getReservationsForDay(day);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isToday
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.5)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontWeight: isToday || isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                            ),
                          ),
                          if (dayReservations.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: dayReservations
                                  .take(3)
                                  .map((r) => Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: _statusColor(r.status),
                                          shape: BoxShape.circle,
                                        ),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectedDayDetails() {
    final reservations = _getReservationsForDay(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              FilledButton.icon(
                onPressed: () => _showAddReservationDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить бронь'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (reservations.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Нет бронирований на этот день',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...reservations.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _showReservationActions(r),
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(r.status).withOpacity(0.15),
                      child: Icon(
                        Icons.access_time,
                        color: _statusColor(r.status),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${r.reservationDate.hour.toString().padLeft(2, '0')}:${r.reservationDate.minute.toString().padLeft(2, '0')} — ${r.customerName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${r.partySize} гостей • Стол #${r.tableId}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(r.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(r.status),
                        style: TextStyle(
                          color: _statusColor(r.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats() {
    final total = _monthReservations.length;
    final dayCounts = <int, int>{};
    for (final r in _monthReservations) {
      final day = r.reservationDate.day;
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }
    final sortedDays = dayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedDays.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика месяца',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                label: 'Всего броней',
                value: '$total',
                icon: Icons.calendar_month,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Среднее/день',
                value: (total / DateTime(
                          _currentMonth.year,
                          _currentMonth.month + 1,
                          0,
                        ).day)
                    .toStringAsFixed(1),
                icon: Icons.trending_up,
              ),
            ],
          ),
          if (top3.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Самые загруженные дни:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            ...top3.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${e.key} ${_monthName(_currentMonth.month)} — ${e.value} брон.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddReservationDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final partySizeController = TextEditingController(text: '2');
    final notesController = TextEditingController();
    DateTime selectedDateTime = _selectedDate;
    int? selectedTableId;
    String selectedStatus = 'pending';
    List<RestaurantTable> tables = [];

    try {
      tables = await _tableRepo.getAll();
    } catch (_) {}

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Телефон',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Дата и время'),
                    subtitle: Text(
                      '${selectedDateTime.day}.${selectedDateTime.month}.${selectedDateTime.year} '
                      '${selectedDateTime.hour.toString().padLeft(2, '0')}:'
                      '${selectedDateTime.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );
                        setDialogState(() {
                          selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time?.hour ?? selectedDateTime.hour,
                            time?.minute ?? selectedDateTime.minute,
                          );
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: partySizeController,
                    decoration: const InputDecoration(
                      labelText: 'Количество гостей',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedTableId,
                    decoration: const InputDecoration(
                      labelText: 'Стол',
                      border: OutlineInputBorder(),
                    ),
                    items: tables
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text('Стол #${t.id} (${t.capacity} мест)'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedTableId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Примечания',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Статус',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _statusRadio('pending', 'Ожидание', setDialogState,
                          selectedStatus, (v) => selectedStatus = v),
                      _statusRadio('confirmed', 'Подтверждено', setDialogState,
                          selectedStatus, (v) => selectedStatus = v),
                      _statusRadio('cancelled', 'Отменено', setDialogState,
                          selectedStatus, (v) => selectedStatus = v),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  if (selectedTableId == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Выберите стол'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final conflicts = await _reservationRepo.getByTableAndDate(
                    selectedTableId!, selectedDateTime,
                  );
                  if (conflicts.isNotEmpty) {
                    if (context.mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Этот стол уже забронирован на выбранную дату'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                  final reservation = Reservation(
                    id: 0,
                    customerName: nameController.text,
                    phone: phoneController.text,
                    reservationDate: selectedDateTime,
                    partySize: int.tryParse(partySizeController.text) ?? 2,
                    tableId: selectedTableId,
                    status: selectedStatus,
                    notes: notesController.text,
                  );
                  await _reservationRepo.create(reservation);
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                },
                child: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReservationActions(Reservation r) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${r.customerName} — Стол #${r.tableId}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditReservationDialog(r);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteReservation(r);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditReservationDialog(Reservation r) async {
    final nameController = TextEditingController(text: r.customerName);
    final phoneController = TextEditingController(text: r.phone ?? '');
    final partySizeController = TextEditingController(text: r.partySize.toString());
    final notesController = TextEditingController(text: r.notes ?? '');
    DateTime selectedDateTime = r.reservationDate;
    int? selectedTableId = r.tableId;
    String selectedStatus = r.status;
    List<RestaurantTable> tables = [];

    try {
      tables = await _tableRepo.getAll();
    } catch (_) {}

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Редактировать бронь'),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Телефон',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Дата и время'),
                    subtitle: Text(
                      '${selectedDateTime.day}.${selectedDateTime.month}.${selectedDateTime.year} '
                      '${selectedDateTime.hour.toString().padLeft(2, '0')}:'
                      '${selectedDateTime.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );
                        setDialogState(() {
                          selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time?.hour ?? selectedDateTime.hour,
                            time?.minute ?? selectedDateTime.minute,
                          );
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: partySizeController,
                    decoration: const InputDecoration(
                      labelText: 'Количество гостей',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedTableId,
                    decoration: const InputDecoration(
                      labelText: 'Стол',
                      border: OutlineInputBorder(),
                    ),
                    items: tables
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text('Стол #${t.id} (${t.capacity} мест)'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedTableId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Примечания',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Статус',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _statusRadio('pending', 'Ожидание', setDialogState,
                          selectedStatus, (v) => selectedStatus = v),
                      _statusRadio('confirmed', 'Подтверждено', setDialogState,
                          selectedStatus, (v) => selectedStatus = v),
                      _statusRadio('cancelled', 'Отменено', setDialogState,
                          selectedStatus, (v) => selectedStatus = v),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  if (selectedTableId == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Выберите стол'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final conflicts = await _reservationRepo.getByTableAndDate(
                    selectedTableId!, selectedDateTime,
                  );
                  final otherConflicts = conflicts.where((c) => c.id != r.id);
                  if (otherConflicts.isNotEmpty) {
                    if (context.mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Этот стол уже забронирован на выбранную дату'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                  final updated = Reservation(
                    id: r.id,
                    customerName: nameController.text,
                    phone: phoneController.text,
                    reservationDate: selectedDateTime,
                    partySize: int.tryParse(partySizeController.text) ?? 2,
                    tableId: selectedTableId,
                    status: selectedStatus,
                    notes: notesController.text,
                  );
                  await _reservationRepo.update(updated);
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteReservation(Reservation r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить бронь'),
        content: Text('Удалить бронь для ${r.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true && r.id != null) {
      await _reservationRepo.delete(r.id!);
      _loadData();
    }
  }

  Widget _statusRadio(
    String value,
    String label,
    StateSetter setDialogState,
    String groupValue,
    ValueChanged<String> onChanged,
  ) {
    return Expanded(
      child: RadioListTile<String>(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 12)),
        value: value,
        groupValue: groupValue,
        onChanged: (v) {
          if (v != null) {
            setDialogState(() => onChanged(v));
          }
        },
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь бронирований'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _previousMonth,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: _goToToday,
                      icon: const Icon(Icons.today, size: 18),
                      label: const Text('Сегодня'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCalendarGrid(),
                  const SizedBox(height: 16),
                  _buildSelectedDayDetails(),
                  const SizedBox(height: 16),
                  _buildMonthlyStats(),
                ],
              ),
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
