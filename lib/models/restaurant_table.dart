import 'converters.dart';

class RestaurantTable {
  final int? id;
  final int tableNumber;
  final int capacity;
  final String zone;
  final String status;
  final DateTime? createdAt;

  const RestaurantTable({
    this.id,
    required this.tableNumber,
    required this.capacity,
    this.zone = 'Основной зал',
    this.status = 'Свободен',
    this.createdAt,
  });

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: parseInt(map['id']),
      tableNumber: parseInt(map['table_number']) ?? 0,
      capacity: parseInt(map['capacity']) ?? 2,
      zone: (map['zone'] ?? 'Основной зал').toString(),
      status: (map['status'] ?? 'Свободен').toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'table_number': tableNumber,
      'capacity': capacity,
      'zone': zone,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  RestaurantTable copyWith({
    int? id,
    int? tableNumber,
    int? capacity,
    String? zone,
    String? status,
    DateTime? createdAt,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      capacity: capacity ?? this.capacity,
      zone: zone ?? this.zone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get statusEmoji {
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
}
