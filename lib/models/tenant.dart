class Tenant {
  const Tenant({
    required this.name,
    required this.tenantId,
  });

  final String name;
  final String tenantId;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tenantId': tenantId,
    };
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      name: map['name'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
    );
  }
}
