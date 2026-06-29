import 'converters.dart';

class InventoryItem {
  final int? id;
  final String name;
  final String category;
  final String? unit;
  final double currentStock;
  final double minStock;
  final double maxStock;
  final double costPerUnit;
  final String? supplier;
  final DateTime? lastRestocked;
  final DateTime? createdAt;

  const InventoryItem({
    this.id,
    required this.name,
    required this.category,
    this.unit = 'кг',
    this.currentStock = 0,
    this.minStock = 0,
    this.maxStock = 100,
    this.costPerUnit = 0,
    this.supplier,
    this.lastRestocked,
    this.createdAt,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: parseInt(map['id']),
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      unit: map['unit']?.toString(),
      currentStock: parseDouble(map['current_stock']),
      minStock: parseDouble(map['min_stock']),
      maxStock: parseDouble(map['max_stock']),
      costPerUnit: parseDouble(map['cost_per_unit']),
      supplier: map['supplier']?.toString(),
      lastRestocked: parseDateTime(map['last_restocked']),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'current_stock': currentStock,
      'min_stock': minStock,
      'max_stock': maxStock,
      'cost_per_unit': costPerUnit,
      'supplier': supplier,
      if (lastRestocked != null) 'last_restocked': lastRestocked!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  InventoryItem copyWith({
    int? id,
    String? name,
    String? category,
    String? unit,
    double? currentStock,
    double? minStock,
    double? maxStock,
    double? costPerUnit,
    String? supplier,
    DateTime? lastRestocked,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      supplier: supplier ?? this.supplier,
      lastRestocked: lastRestocked ?? this.lastRestocked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isLowStock => currentStock <= minStock;
  double get stockPercentage => maxStock > 0 ? (currentStock / maxStock * 100).clamp(0, 100) : 0;
}
