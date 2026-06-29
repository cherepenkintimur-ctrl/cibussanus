import 'converters.dart';

class CashRegister {
  final int? id;
  final int? shiftId;
  final DateTime openTime;
  final DateTime? closeTime;
  final double openingBalance;
  final double closingBalance;
  final double expectedBalance;
  final double discrepancy;
  final double totalCash;
  final double totalCard;
  final double totalOther;
  final int totalOrders;
  final String status;
  final String? notes;
  final DateTime? createdAt;

  const CashRegister({
    this.id,
    this.shiftId,
    required this.openTime,
    this.closeTime,
    this.openingBalance = 0,
    this.closingBalance = 0,
    this.expectedBalance = 0,
    this.discrepancy = 0,
    this.totalCash = 0,
    this.totalCard = 0,
    this.totalOther = 0,
    this.totalOrders = 0,
    this.status = 'Открыта',
    this.notes,
    this.createdAt,
  });

  factory CashRegister.fromMap(Map<String, dynamic> map) {
    return CashRegister(
      id: parseInt(map['id']),
      shiftId: parseInt(map['shift_id']),
      openTime: parseDateTime(map['open_time']) ?? DateTime.now(),
      closeTime: parseDateTime(map['close_time']),
      openingBalance: parseDouble(map['opening_balance']),
      closingBalance: parseDouble(map['closing_balance']),
      expectedBalance: parseDouble(map['expected_balance']),
      discrepancy: parseDouble(map['discrepancy']),
      totalCash: parseDouble(map['total_cash']),
      totalCard: parseDouble(map['total_card']),
      totalOther: parseDouble(map['total_other']),
      totalOrders: parseInt(map['total_orders']) ?? 0,
      status: (map['status'] ?? 'Открыта').toString(),
      notes: map['notes']?.toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (shiftId != null) 'shift_id': shiftId,
      'open_time': openTime.toIso8601String(),
      if (closeTime != null) 'close_time': closeTime!.toIso8601String(),
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'expected_balance': expectedBalance,
      'discrepancy': discrepancy,
      'total_cash': totalCash,
      'total_card': totalCard,
      'total_other': totalOther,
      'total_orders': totalOrders,
      'status': status,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
