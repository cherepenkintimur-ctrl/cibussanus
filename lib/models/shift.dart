import 'converters.dart';

class Shift {
  final int? id;
  final int? waiterId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final String? notes;
  final DateTime? createdAt;

  const Shift({
    this.id,
    this.waiterId,
    required this.startTime,
    this.endTime,
    this.status = 'Активна',
    this.notes,
    this.createdAt,
  });

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: parseInt(map['id']),
      waiterId: parseInt(map['waiter_id']),
      startTime: parseDateTime(map['start_time']) ?? DateTime.now(),
      endTime: parseDateTime(map['end_time']),
      status: (map['status'] ?? 'Активна').toString(),
      notes: map['notes']?.toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (waiterId != null) 'waiter_id': waiterId,
      'start_time': startTime.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      'status': status,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Shift copyWith({
    int? id,
    int? waiterId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return Shift(
      id: id ?? this.id,
      waiterId: waiterId ?? this.waiterId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }
}
