import 'package:flutter_test/flutter_test.dart';
import 'package:lanche_simples/models/item.dart';
import 'package:lanche_simples/services/app_data_service.dart';
import 'package:lanche_simples/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageService', () {
    late LocalStorageService storageService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      storageService = LocalStorageService();
    });

    test('normalizes onboarding payload before persisting', () async {
      await storageService.saveOnboarding(
        tenantId: ' tenant-1001 ',
        employeeName: '  Maria  ',
        employeeCpf: '123.456.789-00',
      );

      expect(await storageService.getTenantId(), 'TENANT-1001');
      expect(await storageService.getEmployeeName(), 'Maria');
      expect(await storageService.getEmployeeCpf(), '12345678900');
      expect(await storageService.isOnboardingComplete(), isTrue);
    });

    test('treats blank values as incomplete onboarding', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tenant_id', '   ');
      await prefs.setString('employee_name', '   ');

      expect(await storageService.isOnboardingComplete(), isFalse);
    });
  });

  group('AppDataService local flows', () {
    late AppDataService dataService;

    const testItem = Item(
      id: 'x-burger',
      tenantId: '',
      name: 'X-Burger',
      price: 15,
      category: 'Lanches',
      createdBy: 'Sistema',
    );

    setUp(() {
      dataService = AppDataService();
    });

    tearDown(() {
      dataService.dispose();
    });

    test('isolates local draft by operator inside the same tenant', () async {
      await dataService.addItemToDraftComanda(
        tenantId: 'tenant-1001',
        operatorName: 'Maria',
        item: testItem,
      );

      final mariaDraft = await dataService
          .watchDraftComanda(
            tenantId: 'TENANT-1001',
            operatorName: 'Maria',
          )
          .first;
      final joaoDraft = await dataService
          .watchDraftComanda(
            tenantId: 'TENANT-1001',
            operatorName: 'João',
          )
          .first;

      expect(mariaDraft.items, hasLength(1));
      expect(joaoDraft.items, isEmpty);
    });

    test('clears only the targeted local operator draft', () async {
      await dataService.addItemToDraftComanda(
        tenantId: 'TENANT-1001',
        operatorName: 'Maria',
        item: testItem,
      );
      await dataService.addItemToDraftComanda(
        tenantId: 'TENANT-1001',
        operatorName: 'João',
        item: testItem,
      );

      await dataService.clearDraftComanda(
        tenantId: 'TENANT-1001',
        operatorName: 'Maria',
      );

      final mariaDraft = await dataService
          .watchDraftComanda(
            tenantId: 'TENANT-1001',
            operatorName: 'Maria',
          )
          .first;
      final joaoDraft = await dataService
          .watchDraftComanda(
            tenantId: 'TENANT-1001',
            operatorName: 'João',
          )
          .first;

      expect(mariaDraft.items, isEmpty);
      expect(joaoDraft.items, hasLength(1));
    });

    test('persists draft identifier and item notes locally', () async {
      await dataService.updateDraftComandaIdentifier(
        tenantId: 'TENANT-1001',
        operatorName: 'Maria',
        identifier: 'Mesa 7',
      );

      await dataService.addItemToDraftComanda(
        tenantId: 'TENANT-1001',
        operatorName: 'Maria',
        draftIdentifier: 'Mesa 7',
        item: testItem.copyWith(notes: 'Sem cebola'),
      );

      final mariaDraft = await dataService
          .watchDraftComanda(
            tenantId: 'TENANT-1001',
            operatorName: 'Maria',
          )
          .first;

      expect(mariaDraft.identifier, 'Mesa 7');
      expect(mariaDraft.items.single.notes, 'Sem cebola');
      expect(mariaDraft.items.single.createdBy, 'Maria');
    });

    test('creates catalog items in local mode', () async {
      final createdItem = await dataService.createCatalogItem(
        tenantId: 'TENANT-1001',
        name: 'Brownie',
        price: 9.5,
        category: 'Sobremesas',
        createdBy: 'Maria',
      );

      final catalog = await dataService.watchCatalog('TENANT-1001').first;

      expect(createdItem.tenantId, 'TENANT-1001');
      expect(catalog.any((item) => item.name == 'Brownie'), isTrue);
      expect(
        catalog.any(
          (item) => item.name == 'Brownie' && item.createdBy == 'Maria',
        ),
        isTrue,
      );
    });

    test('updates catalog items locally including combo composition', () async {
      final createdItem = await dataService.createCatalogItem(
        tenantId: 'TENANT-1001',
        name: 'Combo Almoço',
        price: 22,
        category: 'Combos',
        createdBy: 'Maria',
        comboItems: const <String>['X-Burger', 'Refrigerante Lata'],
      );

      final updatedItem = await dataService.updateCatalogItem(
        tenantId: 'TENANT-1001',
        itemId: createdItem.id,
        name: 'Combo Almoço Executivo',
        price: 24,
        category: 'Combos',
        createdBy: 'Maria',
        comboItems: const <String>['X-Burger', 'Batata G'],
      );

      final catalog = await dataService.watchCatalog('TENANT-1001').first;
      final savedItem = catalog.firstWhere((item) => item.id == createdItem.id);

      expect(updatedItem.name, 'Combo Almoço Executivo');
      expect(savedItem.price, 24);
      expect(savedItem.comboItems, const <String>['X-Burger', 'Batata G']);
    });

    test('creates and filters comandas locally', () async {
      final createdComanda = await dataService.createComanda(
        tenantId: 'TENANT-1001',
        operatorName: 'Maria',
        customerName: 'João Silva',
      );

      final openComandas = await dataService
          .watchComandas(
            tenantId: 'TENANT-1001',
            filter: 'open',
          )
          .first;

      expect(createdComanda.identifier, '#001');
      expect(openComandas, hasLength(1));
      expect(openComandas.single.customerName, 'João Silva');
    });

    test('closes comandas locally and exposes them in closed filter', () async {
      final createdComanda = await dataService.createComanda(
        tenantId: 'TENANT-1001',
        operatorName: 'Maria',
        customerName: 'Maria Souza',
      );

      await dataService.closeComanda(
        tenantId: 'TENANT-1001',
        comandaId: createdComanda.id,
      );

      final closedComandas = await dataService
          .watchComandas(
            tenantId: 'TENANT-1001',
            filter: 'closed',
          )
          .first;

      expect(closedComandas, hasLength(1));
      expect(closedComandas.single.status, 'closed');
      expect(closedComandas.single.customerName, 'Maria Souza');
    });

    test('adds items to an existing local comanda', () async {
      final createdComanda = await dataService.createComanda(
        tenantId: 'TENANT-1001',
        operatorName: 'Maria',
        customerName: 'Mesa 4',
      );

      await dataService.addItemToComanda(
        tenantId: 'TENANT-1001',
        comandaId: createdComanda.id,
        operatorName: 'Maria',
        item: testItem.copyWith(notes: 'Sem cebola'),
      );

      final openComandas = await dataService
          .watchComandas(
            tenantId: 'TENANT-1001',
            filter: 'open',
          )
          .first;

      expect(openComandas.single.items, hasLength(1));
      expect(openComandas.single.items.single.notes, 'Sem cebola');
      expect(openComandas.single.totalAmount, 15);
    });
  });
}
