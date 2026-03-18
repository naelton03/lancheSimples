import 'item.dart';
import 'model_utils.dart';

class Comanda {
  const Comanda({
    required this.id,
    required this.tenantId,
    required this.identifier,
    required this.items,
    required this.createdBy,
    required this.timestamp,
    required this.status,
    required this.totalAmount,
  });

  final String id;
  final String tenantId;
  final String identifier;
  final List<Item> items;
  final String createdBy;
  final DateTime timestamp;
  final String status;
  final double totalAmount;

  Comanda copyWith({
    String? id,
    String? tenantId,
    String? identifier,
    List<Item>? items,
    String? createdBy,
    DateTime? timestamp,
    String? status,
    double? totalAmount,
  }) {
    return Comanda(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      identifier: identifier ?? this.identifier,
      items: items ?? this.items,
      createdBy: createdBy ?? this.createdBy,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'identifier': identifier,
      'items': items.map((item) => item.toMap()).toList(),
      'createdBy': createdBy,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'totalAmount': totalAmount,
    };
  }

  factory Comanda.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];

    return Comanda(
      id: map['id'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
      identifier: map['identifier'] as String? ?? '',
      items: rawItems
          .map((item) => Item.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdBy: map['createdBy'] as String? ?? '',
      timestamp: parseDateTimeOrEpoch(map['timestamp']),
      status: map['status'] as String? ?? 'open',
      totalAmount: parseDouble(map['totalAmount']),
    );
  }
}
