import '../models/item.dart';
import '../models/tenant.dart';

class MockDataService {
  static const masterCode = '13356436481';

  final List<Tenant> _tenants = <Tenant>[
    Tenant(
      name: 'Lanche Central',
      tenantId: 'TENANT-1001',
      createdAt: DateTime.parse('2026-03-10T12:00:00.000Z'),
    ),
    Tenant(
      name: 'Burger do Bairro',
      tenantId: 'TENANT-1002',
      createdAt: DateTime.parse('2026-03-11T12:00:00.000Z'),
    ),
  ];

  final List<Item> _catalogTemplate = <Item>[
    Item(
      id: 'x-burger',
      tenantId: '',
      name: 'X-Burger',
      price: 15,
      category: 'Lanches',
      createdBy: 'Sistema',
    ),
    Item(
      id: 'x-salada',
      tenantId: '',
      name: 'X-Salada',
      price: 17,
      category: 'Lanches',
      createdBy: 'Sistema',
    ),
    Item(
      id: 'batata-g',
      tenantId: '',
      name: 'Batata G',
      price: 12,
      category: 'Acompanhamentos',
      createdBy: 'Sistema',
    ),
    Item(
      id: 'refrigerante-lata',
      tenantId: '',
      name: 'Refrigerante Lata',
      price: 6,
      category: 'Bebidas',
      createdBy: 'Sistema',
    ),
    Item(
      id: 'combo-familia',
      tenantId: '',
      name: 'Combo Família',
      price: 39.9,
      category: 'Combos',
      createdBy: 'Sistema',
    ),
  ];

  final Map<String, List<Item>> _customCatalogByTenant = <String, List<Item>>{};

  List<Tenant> getTenants() {
    final tenants = List<Tenant>.from(_tenants);
    tenants.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return List<Tenant>.unmodifiable(tenants);
  }

  List<Item> getCatalogForTenant(String tenantId) {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    final seededItems = _catalogTemplate
        .map((item) => item.copyWith(tenantId: normalizedTenantId))
        .toList(growable: false);
    final customItems = _customCatalogByTenant[normalizedTenantId] ?? const <Item>[];

    final catalogById = <String, Item>{
      for (final item in seededItems) item.id: item,
      for (final item in customItems) item.id: item,
    };

    final catalog = catalogById.values.toList(growable: false)
      ..sort(
        (a, b) {
          final categorySort = a.category.compareTo(b.category);
          if (categorySort != 0) {
            return categorySort;
          }
          return a.name.compareTo(b.name);
        },
      );
    return List<Item>.unmodifiable(catalog);
  }

  Item createCatalogItem(Item item) {
    final normalizedTenantId = item.tenantId.trim().toUpperCase();
    final tenantItems = _customCatalogByTenant.putIfAbsent(
      normalizedTenantId,
      () => <Item>[],
    );
    final createdItem = item.copyWith(tenantId: normalizedTenantId);
    tenantItems.add(createdItem);
    return createdItem;
  }

  Item updateCatalogItem(Item item) {
    final normalizedTenantId = item.tenantId.trim().toUpperCase();
    final tenantItems = _customCatalogByTenant.putIfAbsent(
      normalizedTenantId,
      () => <Item>[],
    );
    final updatedItem = item.copyWith(tenantId: normalizedTenantId);
    final existingIndex = tenantItems.indexWhere((entry) => entry.id == updatedItem.id);
    if (existingIndex >= 0) {
      tenantItems[existingIndex] = updatedItem;
    } else {
      tenantItems.add(updatedItem);
    }
    return updatedItem;
  }

  List<Item> getItemsByCategory(String tenantId, String? category) {
    final items = getCatalogForTenant(tenantId);
    if (category == null || category == 'Todos') {
      return items;
    }

    return items.where((item) => item.category == category).toList(growable: false);
  }

  List<String> getCategoriesForItems(List<Item> items) {
    final categories = items.map((item) => item.category).toSet().toList()..sort();
    return <String>['Todos', ...categories];
  }

  Tenant createTenant(String name) {
    final normalizedName = name.trim();
    for (final tenant in _tenants) {
      if (tenant.name.toLowerCase() == normalizedName.toLowerCase()) {
        return tenant;
      }
    }

    final tenant = Tenant(
      name: normalizedName,
      tenantId: 'TENANT-${1000 + _tenants.length + 1}',
      createdAt: DateTime.now().toUtc(),
    );
    _tenants.insert(0, tenant);
    return tenant;
  }

  Tenant? getTenantById(String tenantId) {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    for (final tenant in _tenants) {
      if (tenant.tenantId == normalizedTenantId) {
        return tenant;
      }
    }

    return null;
  }

  bool isValidTenant(String tenantId) {
    return getTenantById(tenantId) != null;
  }
}
