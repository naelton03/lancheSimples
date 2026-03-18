import '../models/item.dart';
import '../models/tenant.dart';

class MockDataService {
  static const masterCode = '13356436481';

  final List<Tenant> _tenants = <Tenant>[
    const Tenant(name: 'Lanche Central', tenantId: 'TENANT-1001'),
    const Tenant(name: 'Burger do Bairro', tenantId: 'TENANT-1002'),
  ];

  final List<Item> _items = const <Item>[
    Item(
      name: 'X-Burger',
      price: 15,
      category: 'Lanches',
      createdBy: 'Sistema',
    ),
    Item(
      name: 'X-Salada',
      price: 17,
      category: 'Lanches',
      createdBy: 'Sistema',
    ),
    Item(
      name: 'Batata G',
      price: 12,
      category: 'Acompanhamentos',
      createdBy: 'Sistema',
    ),
    Item(
      name: 'Refrigerante Lata',
      price: 6,
      category: 'Bebidas',
      createdBy: 'Sistema',
    ),
    Item(
      name: 'Combo Família',
      price: 39.9,
      category: 'Combos',
      createdBy: 'Sistema',
    ),
  ];

  List<Tenant> getTenants() => List<Tenant>.unmodifiable(_tenants);

  List<Item> getItemsByCategory(String? category) {
    if (category == null || category == 'Todos') {
      return List<Item>.unmodifiable(_items);
    }

    return _items.where((item) => item.category == category).toList();
  }

  List<String> getCategories() {
    final categories = _items.map((item) => item.category).toSet().toList()..sort();
    return <String>['Todos', ...categories];
  }

  Tenant createTenant(String name) {
    final tenant = Tenant(
      name: name,
      tenantId: 'TENANT-${1000 + _tenants.length + 1}',
    );
    _tenants.insert(0, tenant);
    return tenant;
  }

  bool isValidTenant(String tenantId) {
    return _tenants.any((tenant) => tenant.tenantId == tenantId.trim());
  }
}
