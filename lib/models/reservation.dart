import 'converters.dart';

class Reservation {
  final int? id;
  final int? tableId;
  final String customerName;
  final String? phone;
  final DateTime reservationDate;
  final int partySize;
  final String status;
  final String? notes;
  final DateTime? createdAt;

  const Reservation({
    this.id,
    this.tableId,
    required this.customerName,
    this.phone,
    required this.reservationDate,
    required this.partySize,
    this.status = 'Подтверждено',
    this.notes,
    this.createdAt,
  });

  factory Reservation.fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: parseInt(map['id']),
      tableId: parseInt(map['table_id']),
      customerName: (map['customer_name'] ?? '').toString(),
      phone: map['phone']?.toString(),
      reservationDate: parseDateTime(map['reservation_date']) ?? DateTime.now(),
      partySize: parseInt(map['party_size']) ?? 1,
      status: (map['status'] ?? 'Подтверждено').toString(),
      notes: map['notes']?.toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (tableId != null) 'table_id': tableId,
      'customer_name': customerName,
      'phone': phone,
      'reservation_date': reservationDate.toIso8601String(),
      'party_size': partySize,
      'status': status,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Reservation copyWith({
    int? id,
    int? tableId,
    String? customerName,
    String? phone,
    DateTime? reservationDate,
    int? partySize,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      reservationDate: reservationDate ?? this.reservationDate,
      partySize: partySize ?? this.partySize,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
