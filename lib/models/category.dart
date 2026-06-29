import 'converters.dart';

class Category {
  final int? id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  const Category({
    this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: parseInt(map['id']),
      name: (map['name'] ?? '').toString(),
      description: map['description']?.toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
