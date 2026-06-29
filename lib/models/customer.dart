import 'converters.dart';

class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final String? allergies;
  final int visitCount;
  final double totalSpent;
  final DateTime? lastVisit;
  final DateTime? createdAt;

  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.allergies,
    this.visitCount = 0,
    this.totalSpent = 0,
    this.lastVisit,
    this.createdAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: parseInt(map['id']),
      name: (map['name'] ?? '').toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      notes: map['notes']?.toString(),
      allergies: map['allergies']?.toString(),
      visitCount: parseInt(map['visit_count']) ?? 0,
      totalSpent: parseDouble(map['total_spent']),
      lastVisit: parseDateTime(map['last_visit']),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'allergies': allergies,
      'visit_count': visitCount,
      'total_spent': totalSpent,
      if (lastVisit != null) 'last_visit': lastVisit!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
    String? allergies,
    int? visitCount,
    double? totalSpent,
    DateTime? lastVisit,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      allergies: allergies ?? this.allergies,
      visitCount: visitCount ?? this.visitCount,
      totalSpent: totalSpent ?? this.totalSpent,
      lastVisit: lastVisit ?? this.lastVisit,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get loyaltyTier {
    if (totalSpent >= 100000 || visitCount >= 50) return '💎 Платиновый';
    if (totalSpent >= 50000 || visitCount >= 25) return '🥇 Золотой';
    if (totalSpent >= 20000 || visitCount >= 10) return '🥈 Серебряный';
    if (visitCount >= 3) return '🥉 Бронзовый';
    return 'Гость';
  }
}
