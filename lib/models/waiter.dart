import 'converters.dart';

class Waiter {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String role;
  final bool isActive;
  final double baseSalary;
  final DateTime? hireDate;
  final DateTime? createdAt;

  const Waiter({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.role = 'Официант',
    this.isActive = true,
    this.baseSalary = 0,
    this.hireDate,
    this.createdAt,
  });

  factory Waiter.fromMap(Map<String, dynamic> map) {
    return Waiter(
      id: parseInt(map['id']),
      name: (map['name'] ?? '').toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      role: (map['role'] ?? 'Официант').toString(),
      isActive: parseBool(map['is_active'], defaultValue: true),
      baseSalary: parseDouble(map['base_salary']),
      hireDate: parseDateTime(map['hire_date']),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'base_salary': baseSalary,
      if (hireDate != null) 'hire_date': hireDate!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Waiter copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? role,
    bool? isActive,
    double? baseSalary,
    DateTime? hireDate,
    DateTime? createdAt,
  }) {
    return Waiter(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      baseSalary: baseSalary ?? this.baseSalary,
      hireDate: hireDate ?? this.hireDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
