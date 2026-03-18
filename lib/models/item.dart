class Item {
  const Item({
    required this.name,
    required this.price,
    required this.category,
    required this.createdBy,
  });

  final String name;
  final double price;
  final String category;
  final String createdBy;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category,
      'createdBy': createdBy,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];

    return Item(
      name: map['name'] as String? ?? '',
      price: rawPrice is num ? rawPrice.toDouble() : 0,
      category: map['category'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
    );
  }
}
