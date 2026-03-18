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

  group('AppDataService local draft comanda', () {
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
  });
}
