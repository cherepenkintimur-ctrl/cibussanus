import 'package:flutter/material.dart';
import '../../models/waiter_schedule.dart';
import '../../models/waiter.dart';
import '../../models/converters.dart';
import '../../repositories/waiter_schedule_repository.dart';
import '../../repositories/waiter_repository.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final WaiterScheduleRepository _scheduleRepo = const WaiterScheduleRepository();
  final WaiterRepository _waiterRepo = const WaiterRepository();

  List<Waiter> _waiters = [];
  List<WaiterSchedule> _schedules = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  DateTime _weekStart = DateTime.now();
  int _totalShiftsThisWeek = 0;

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(DateTime.now());
    _loadData();
  }

  DateTime _getWeekStart(DateTime date) {
    final diff = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - diff);
  }

  List<DateTime> get _weekDays {
    return List.generate(7, (i) => _weekStart.add(Duration(days: i)));
  }

  String _formatDateRange() {
    final end = _weekStart.add(const Duration(days: 6));
    final startStr =
        '${_weekStart.day.toString().padLeft(2, '0')}.${_weekStart.month.toString().padLeft(2, '0')}.${_weekStart.year}';
    final endStr =
        '${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}';
    return '$startStr — $endStr';
  }

  bool _isCurrentWeek() {
    final nowWeekStart = _getWeekStart(DateTime.now());
    return _weekStart.year == nowWeekStart.year &&
        _weekStart.month == nowWeekStart.month &&
        _weekStart.day == nowWeekStart.day;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _scheduleRepo.getWeekSchedule(_weekStart),
        _waiterRepo.getAll(onlyActive: true),
        _scheduleRepo.getScheduleStats(_weekStart),
      ]);
      if (!mounted) return;
      final schedules = results[0] as List<WaiterSchedule>;
      setState(() {
        _schedules = schedules;
        _waiters = results[1] as List<Waiter>;
        _stats = results[2] as Map<String, dynamic>;
        _totalShiftsThisWeek = schedules.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    }
  }

  void _previousWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _loadData();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _loadData();
  }

  WaiterSchedule? _getScheduleFor(Waiter waiter, DateTime date) {
    try {
      return _schedules.firstWhere(
        (s) =>
            s.waiterId == waiter.id &&
            s.date.year == date.year &&
            s.date.month == date.month &&
            s.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Выполнена':
        return Colors.green;
      case 'Запланирована':
        return Colors.blue;
      case 'Отменена':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getDayLabel(DateTime date) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[date.weekday - 1];
  }

  Future<void> _showAddShiftDialog({WaiterSchedule? existing, DateTime? defaultDate}) async {
    Waiter? selectedWaiter = existing != null
        ? _waiters.firstWhere((w) => w.id == existing.waiterId, orElse: () => _waiters.first)
        : null;
    DateTime selectedDate = defaultDate ?? DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    final notesController = TextEditingController(text: existing?.notes ?? '');

    if (existing != null) {
      final parts = existing.startTime.split(':');
      if (parts.length >= 2) {
        startTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      final endParts = existing.endTime.split(':');
      if (endParts.length >= 2) {
        endTime = TimeOfDay(
          hour: int.tryParse(endParts[0]) ?? 18,
          minute: int.tryParse(endParts[1]) ?? 0,
        );
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Добавить смену' : 'Редактировать смену'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Waiter>(
                  decoration: const InputDecoration(
                    labelText: 'Официант',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedWaiter,
                  items: _waiters
                      .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedWaiter = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Дата'),
                  subtitle: Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: _weekStart,
                      lastDate: _weekStart.add(const Duration(days: 6)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Время начала'),
                  subtitle: Text(
                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (picked != null) {
                      setDialogState(() => startTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Время окончания'),
                  subtitle: Text(
                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                    );
                    if (picked != null) {
                      setDialogState(() => endTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Заметки',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
              onPressed: () {
                if (selectedWaiter == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Выберите официанта')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'waiter': selectedWaiter,
                  'date': selectedDate,
                  'startTime':
                      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                  'endTime':
                      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                  'notes': notesController.text,
                });
              },
              child: Text(existing == null ? 'Добавить' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final schedule = WaiterSchedule(
          id: existing?.id,
          waiterId: result['waiter'].id,
          date: result['date'],
          startTime: result['startTime'],
          endTime: result['endTime'],
          notes: result['notes'].isNotEmpty ? result['notes'] : null,
          status: existing?.status ?? 'Запланирована',
        );
        if (existing == null) {
          await _scheduleRepo.create(schedule);
        } else {
          await _scheduleRepo.update(schedule);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null ? 'Смена добавлена' : 'Смена обновлена',
            ),
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _showShiftContextMenu(WaiterSchedule schedule) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(context);
                _showAddShiftDialog(existing: schedule);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Удалить смену?'),
                    content: const Text('Вы уверены, что хотите удалить эту смену?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && schedule.id != null) {
                  try {
                    await _scheduleRepo.delete(schedule.id!);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Смена удалена')),
                    );
                    _loadData();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Изменить статус'),
              onTap: () {
                Navigator.pop(context);
                _showStatusPicker(schedule);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker(WaiterSchedule schedule) {
    final statuses = ['Запланирована', 'Выполнена', 'Отменена'];
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Выберите статус',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...statuses.map((status) => ListTile(
                  leading: Icon(
                    status == 'Выполнена'
                        ? Icons.check_circle
                        : status == 'Отменена'
                            ? Icons.cancel
                            : Icons.schedule,
                    color: _getStatusColor(status),
                  ),
                  title: Text(status),
                  trailing: schedule.status == status
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await _scheduleRepo.updateStatus(schedule.id!, status);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Статус изменён на "$status"')),
                      );
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')),
                      );
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToNextWeek() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Копировать расписание'),
        content: const Text(
          'Скопировать расписание на следующую неделю?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Копировать'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final nextWeekStart = _weekStart.add(const Duration(days: 7));
      for (final schedule in _schedules) {
        final newDate = schedule.date.add(const Duration(days: 7));
        if (newDate.isBefore(nextWeekStart.add(const Duration(days: 7)))) {
          await _scheduleRepo.create(
            WaiterSchedule(
              waiterId: schedule.waiterId,
              date: newDate,
              startTime: schedule.startTime,
              endTime: schedule.endTime,
              status: 'Запланирована',
              notes: schedule.notes,
            ),
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Расписание скопировано')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _clearSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить расписание'),
        content: const Text(
          'Удалить все смены на текущую неделю?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      for (final schedule in _schedules) {
        if (schedule.id != null) {
          await _scheduleRepo.delete(schedule.id!);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Расписание очищено')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Widget _buildWeekNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _previousWeek,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Неделя: ${_formatDateRange()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_isCurrentWeek())
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Текущая неделя',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _nextWeek,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleGrid() {
    if (_waiters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Нет активных официантов'),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                // Waiter name column header
                Container(
                  width: 140,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Официант',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // Day headers
                ..._weekDays.map((date) {
                  final isToday = date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;
                  return Container(
                    width: 100,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDayLabel(date),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isToday
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : null,
                          ),
                        ),
                        Text(
                          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isToday
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            // Waiter rows
            ..._waiters.map((waiter) {
              return Row(
                children: [
                  // Waiter name
                  Container(
                    width: 140,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      waiter.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Day cells
                  ..._weekDays.map((date) {
                    final schedule = _getScheduleFor(waiter, date);
                    return GestureDetector(
                      onLongPress: schedule != null
                          ? () => _showShiftContextMenu(schedule)
                          : null,
                      onTap: () {
                        _showAddShiftDialog(
                          existing: schedule,
                          defaultDate: date,
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 72,
                        decoration: BoxDecoration(
                          color: schedule != null
                              ? _getStatusColor(schedule.status).withOpacity(0.15)
                              : null,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(4),
                        child: schedule != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${schedule.startTime}-${schedule.endTime}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(schedule.status),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(schedule.status)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      schedule.status,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: _getStatusColor(schedule.status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Icon(
                                Icons.add_circle_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final byWaiter = _stats['by_waiter'] as List<dynamic>?;

    String busiestDay = '—';
    final dayShiftCount = <String, int>{};
    for (final schedule in _schedules) {
      final dayLabel = _getDayLabel(schedule.date);
      dayShiftCount[dayLabel] = (dayShiftCount[dayLabel] ?? 0) + 1;
    }
    if (dayShiftCount.isNotEmpty) {
      final maxEntry = dayShiftCount.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      busiestDay = maxEntry.key;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика недели',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_totalShiftsThisWeek',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Всего смен',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          busiestDay,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Самый загруженный день',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (byWaiter != null && byWaiter.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  for (final row in byWaiter)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        child: Text(
                          '${row['shift_count'] ?? 0}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '${row['name'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Text(
                        '${(row['total_hours'] ?? 0.0).toStringAsFixed(1)} ч',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _copyToNextWeek,
              icon: const Icon(Icons.copy),
              label: const Text('Копировать на след. неделю'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearSchedule,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Очистить'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание'),
        actions: [
          IconButton(
            onPressed: () => _showAddShiftDialog(),
            icon: const Icon(Icons.add),
            tooltip: 'Добавить смену',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddShiftDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить смену'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  _buildWeekNavigation(),
                  const SizedBox(height: 8),
                  _buildScheduleGrid(),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  _buildStatsSection(),
                ],
              ),
            ),
    );
  }
}
