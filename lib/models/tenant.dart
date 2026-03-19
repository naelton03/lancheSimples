import 'model_utils.dart';

class Tenant {
  const Tenant({
    required this.name,
    required this.tenantId,
    this.createdAt,
  });

  final String name;
  final String tenantId;
  final DateTime? createdAt;

  Tenant copyWith({
    String? name,
    String? tenantId,
    DateTime? createdAt,
  }) {
    return Tenant(
      name: name ?? this.name,
      tenantId: tenantId ?? this.tenantId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tenantId': tenantId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      name: map['name'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
      createdAt: parseNullableDateTime(map['createdAt']),
    );
  }
}
