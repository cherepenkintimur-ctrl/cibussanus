import 'converters.dart';

class Discount {
  final int? id;
  final String code;
  final String description;
  final String type;
  final double value;
  final double? minOrderAmount;
  final double? maxDiscountAmount;
  final DateTime validFrom;
  final DateTime validTo;
  final bool isActive;
  final int? usageLimit;
  final int usageCount;
  final DateTime? createdAt;

  const Discount({
    this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    this.minOrderAmount,
    this.maxDiscountAmount,
    required this.validFrom,
    required this.validTo,
    this.isActive = true,
    this.usageLimit,
    this.usageCount = 0,
    this.createdAt,
  });

  factory Discount.fromMap(Map<String, dynamic> map) {
    return Discount(
      id: parseInt(map['id']),
      code: (map['code'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      type: (map['type'] ?? 'percent').toString(),
      value: parseDouble(map['value']),
      minOrderAmount: map['min_order_amount'] != null ? parseDouble(map['min_order_amount']) : null,
      maxDiscountAmount: map['max_discount_amount'] != null ? parseDouble(map['max_discount_amount']) : null,
      validFrom: parseDateTime(map['valid_from']) ?? DateTime.now(),
      validTo: parseDateTime(map['valid_to']) ?? DateTime.now().add(const Duration(days: 30)),
      isActive: parseBool(map['is_active'], defaultValue: true),
      usageLimit: parseInt(map['usage_limit']),
      usageCount: parseInt(map['usage_count']) ?? 0,
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'description': description,
      'type': type,
      'value': value,
      'min_order_amount': minOrderAmount,
      'max_discount_amount': maxDiscountAmount,
      'valid_from': validFrom.toIso8601String(),
      'valid_to': validTo.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'usage_limit': usageLimit,
      'usage_count': usageCount,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  double calculateDiscount(double orderAmount) {
    if (!isActive) return 0;
    if (minOrderAmount != null && orderAmount < minOrderAmount!) return 0;
    if (usageLimit != null && usageCount >= usageLimit!) return 0;

    double discount;
    if (type == 'percent') {
      discount = orderAmount * (value / 100);
    } else {
      discount = value;
    }

    if (maxDiscountAmount != null && discount > maxDiscountAmount!) {
      discount = maxDiscountAmount!;
    }

    return discount;
  }

  Discount copyWith({
    int? id,
    String? code,
    String? description,
    String? type,
    double? value,
    double? minOrderAmount,
    double? maxDiscountAmount,
    DateTime? validFrom,
    DateTime? validTo,
    bool? isActive,
    int? usageLimit,
    int? usageCount,
    DateTime? createdAt,
  }) {
    return Discount(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      isActive: isActive ?? this.isActive,
      usageLimit: usageLimit ?? this.usageLimit,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
