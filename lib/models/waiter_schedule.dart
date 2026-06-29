import 'converters.dart';

class WaiterSchedule {
  final int? id;
  final int? waiterId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String status;
  final String? notes;
  final DateTime? createdAt;

  const WaiterSchedule({
    this.id,
    this.waiterId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status = 'Запланирована',
    this.notes,
    this.createdAt,
  });

  factory WaiterSchedule.fromMap(Map<String, dynamic> map) {
    return WaiterSchedule(
      id: parseInt(map['id']),
      waiterId: parseInt(map['waiter_id']),
      date: parseDateTime(map['date']) ?? DateTime.now(),
      startTime: (map['start_time'] ?? '09:00').toString(),
      endTime: (map['end_time'] ?? '18:00').toString(),
      status: (map['status'] ?? 'Запланирована').toString(),
      notes: map['notes']?.toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (waiterId != null) 'waiter_id': waiterId,
      'date': date.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  WaiterSchedule copyWith({
    int? id,
    int? waiterId,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return WaiterSchedule(
      id: id ?? this.id,
      waiterId: waiterId ?? this.waiterId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
