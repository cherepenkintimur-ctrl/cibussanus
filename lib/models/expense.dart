import 'converters.dart';

class Expense {
  final int? id;
  final String category;
  final String description;
  final double amount;
  final DateTime expenseDate;
  final String? receiptNumber;
  final String? supplier;
  final DateTime? createdAt;

  const Expense({
    this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.expenseDate,
    this.receiptNumber,
    this.supplier,
    this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: parseInt(map['id']),
      category: (map['category'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      amount: parseDouble(map['amount']),
      expenseDate: parseDateTime(map['expense_date']) ?? DateTime.now(),
      receiptNumber: map['receipt_number']?.toString(),
      supplier: map['supplier']?.toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'description': description,
      'amount': amount,
      'expense_date': expenseDate.toIso8601String(),
      'receipt_number': receiptNumber,
      'supplier': supplier,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Expense copyWith({
    int? id,
    String? category,
    String? description,
    double? amount,
    DateTime? expenseDate,
    String? receiptNumber,
    String? supplier,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      supplier: supplier ?? this.supplier,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
