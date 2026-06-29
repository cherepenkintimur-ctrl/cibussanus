import 'converters.dart';

class Dish {
  final int? id;
  final int? categoryId;
  final String name;
  final double price;
  final String? description;
  final String? volume;
  final String? unit;
  final bool isActive;
  final DateTime? createdAt;

  const Dish({
    this.id,
    this.categoryId,
    required this.name,
    required this.price,
    this.description,
    this.volume,
    this.unit = 'шт',
    this.isActive = true,
    this.createdAt,
  });

  factory Dish.fromMap(Map<String, dynamic> map) {
    return Dish(
      id: parseInt(map['id']),
      categoryId: parseInt(map['category_id']),
      name: (map['name'] ?? '').toString(),
      price: parseDouble(map['price']),
      description: map['description']?.toString(),
      volume: map['volume']?.toString(),
      unit: map['unit']?.toString() ?? 'шт',
      isActive: parseBool(map['is_active'], defaultValue: true),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'description': description,
      'volume': volume,
      'unit': unit,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  Dish copyWith({
    int? id,
    int? categoryId,
    String? name,
    double? price,
    String? description,
    String? volume,
    String? unit,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Dish(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      volume: volume ?? this.volume,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
