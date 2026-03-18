import 'model_utils.dart';

class Item {
  const Item({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.price,
    required this.category,
    required this.createdBy,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final double price;
  final String category;
  final String createdBy;
  final DateTime? createdAt;

  Item copyWith({
    String? id,
    String? tenantId,
    String? name,
    double? price,
    String? category,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Item(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'price': price,
      'category': category,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: parseDouble(map['price']),
      category: map['category'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseNullableDateTime(map['createdAt']),
    );
  }
}
