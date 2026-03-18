import 'item.dart';

class Comanda {
  const Comanda({
    required this.id,
    required this.items,
    required this.createdBy,
    required this.timestamp,
  });

  final String id;
  final List<Item> items;
  final String createdBy;
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((item) => item.toMap()).toList(),
      'createdBy': createdBy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Comanda.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];

    return Comanda(
      id: map['id'] as String? ?? '',
      items: rawItems
          .map((item) => Item.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdBy: map['createdBy'] as String? ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
