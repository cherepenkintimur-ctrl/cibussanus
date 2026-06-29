import 'package:flutter/material.dart';
import '../../models/shift.dart';
import '../../models/waiter.dart';
import '../../repositories/shift_repository.dart';
import '../../repositories/waiter_repository.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final ShiftRepository _shiftRepo = const ShiftRepository();
  final WaiterRepository _waiterRepo = const WaiterRepository();

  List<Shift> _activeShifts = [];
  List<Shift> _allShifts = [];
  List<Waiter> _waiters = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  Waiter? _selectedQuickWaiter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _shiftRepo.getActive(),
        _shiftRepo.getAll(),
        _waiterRepo.getAll(onlyActive: true),
        _shiftRepo.getShiftStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _activeShifts = results[0] as List<Shift>;
        _allShifts = results[1] as List<Shift>;
        _waiters = results[2] as List<Waiter>;
        _stats = results[3] as Map<String, dynamic>;
        if (_selectedQuickWaiter != null) {
          _selectedQuickWaiter = _waiters.where((w) => w.id == _selectedQuickWaiter!.id).firstOrNull;
        }
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

  Future<void> _endShift(Shift shift) async {
    try {
      await _shiftRepo.endShift(shift.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Смена завершена')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _quickStartShift() async {
    if (_selectedQuickWaiter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите официанта')),
      );
      return;
    }
    try {
      await _shiftRepo.create(
        Shift(waiterId: _selectedQuickWaiter!.id, startTime: DateTime.now()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Смена начата')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _showCreateShiftDialog() async {
    Waiter? selectedWaiter;
    final notesController = TextEditingController();
    DateTime startTime = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новая смена'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Waiter>(
                  decoration: const InputDecoration(
                    labelText: 'Официант',
                    border: OutlineInputBorder(),
                  ),
                  items: _waiters
                      .map((w) => DropdownMenuItem(
                            value: w,
                            child: Text(w.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedWaiter = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Время начала'),
                  subtitle: Text(
                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(startTime),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startTime = DateTime(
                          startTime.year,
                          startTime.month,
                          startTime.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
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
                  'startTime': startTime,
                  'notes': notesController.text,
                });
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await _shiftRepo.create(
          Shift(
            waiterId: result['waiter'].id,
            startTime: result['startTime'],
            notes: result['notes'].isNotEmpty ? result['notes'] : null,
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Смена создана')),
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

  String _formatDuration(Duration d) {
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  }

  String _getWaiterName(int? waiterId) {
    if (waiterId == null) return 'Неизвестный';
    final waiter = _waiters.where((w) => w.id == waiterId);
    return waiter.isNotEmpty ? waiter.first.name : 'Неизвестный';
  }

  Map<DateTime, List<Shift>> _groupShiftsByDate(List<Shift> shifts) {
    final grouped = <DateTime, List<Shift>>{};
    for (final shift in shifts) {
      final date = DateTime(
        shift.startTime.year,
        shift.startTime.month,
        shift.startTime.day,
      );
      grouped.putIfAbsent(date, () => []).add(shift);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  Widget _buildActiveShiftsSection() {
    if (_activeShifts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Активные смены (${_activeShifts.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...List.generate(_activeShifts.length, (index) {
          final shift = _activeShifts[index];
          final now = DateTime.now();
          final elapsed = now.difference(shift.startTime);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getWaiterName(shift.waiterId),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Активна',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Начало: ${formatDateTime(shift.startTime)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Длительность: ${_formatDuration(elapsed)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _endShift(shift),
                      icon: const Icon(Icons.stop, size: 16),
                      label: const Text('Завершить смену'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAllShiftsSection() {
    final grouped = _groupShiftsByDate(_allShifts);
    if (grouped.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Нет смен'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Все смены',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...grouped.entries.map((entry) {
          final date = entry.key;
          final shifts = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
              ...shifts.map((shift) {
                final isActive = shift.endTime == null;
                final duration = shift.endTime != null
                    ? shift.endTime!.difference(shift.startTime)
                    : DateTime.now().difference(shift.startTime);
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      child: Icon(
                        isActive ? Icons.work : Icons.work_outline,
                        color: isActive
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.outline,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _getWaiterName(shift.waiterId),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${formatTime(shift.startTime)} - ${shift.endTime != null ? formatTime(shift.endTime!) : 'Активна'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Text(
                      _formatDuration(duration),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStatsSection() {
    if (_stats.isEmpty || _stats['byWaiter'] == null) {
      return const SizedBox.shrink();
    }
    final byWaiter = _stats['byWaiter'] as List<Map<String, dynamic>>;
    if (byWaiter.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Статистика',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < byWaiter.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .secondaryContainer,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    byWaiter[i]['waiterName'] ?? 'Неизвестный',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${byWaiter[i]['shiftCount'] ?? 0} смен',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Text(
                    '${(byWaiter[i]['totalHours'] ?? 0.0).toStringAsFixed(1)} ч',
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
    );
  }

  Widget _buildQuickStartSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<Waiter>(
              decoration: const InputDecoration(
                labelText: 'Быстрый старт',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: _selectedQuickWaiter,
              items: _waiters
                  .map((w) => DropdownMenuItem(
                        value: w,
                        child: Text(w.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedQuickWaiter = value);
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _quickStartShift,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Начать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Смены'),
        actions: [
          IconButton(
            onPressed: _showCreateShiftDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Новая смена',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateShiftDialog,
        icon: const Icon(Icons.add),
        label: const Text('Новая смена'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  _buildQuickStartSection(),
                  _buildActiveShiftsSection(),
                  _buildStatsSection(),
                  _buildAllShiftsSection(),
                ],
              ),
            ),
    );
  }
}
