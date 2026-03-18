import 'package:flutter_test/flutter_test.dart';
import 'package:lanche_simples/models/comanda.dart';
import 'package:lanche_simples/models/item.dart';
import 'package:lanche_simples/models/tenant.dart';

void main() {
  group('model serialization', () {
    test('Tenant serializes and deserializes correctly', () {
      const tenant = Tenant(name: 'Lanche Central', tenantId: 'TENANT-1001');

      final map = tenant.toMap();
      final restored = Tenant.fromMap(map);

      expect(restored.name, tenant.name);
      expect(restored.tenantId, tenant.tenantId);
    });

    test('Item serializes and deserializes correctly', () {
      const item = Item(
        name: 'X-Burger',
        price: 15.5,
        category: 'Lanches',
        createdBy: 'Maria',
      );

      final map = item.toMap();
      final restored = Item.fromMap(map);

      expect(restored.name, item.name);
      expect(restored.price, item.price);
      expect(restored.category, item.category);
      expect(restored.createdBy, item.createdBy);
    });

    test('Comanda serializes and deserializes correctly', () {
      final comanda = Comanda(
        id: 'mesa-10',
        items: const <Item>[
          Item(
            name: 'Batata G',
            price: 12,
            category: 'Acompanhamentos',
            createdBy: 'João',
          ),
        ],
        createdBy: 'João',
        timestamp: DateTime.parse('2026-03-18T12:00:00.000Z'),
      );

      final map = comanda.toMap();
      final restored = Comanda.fromMap(map);

      expect(restored.id, comanda.id);
      expect(restored.createdBy, comanda.createdBy);
      expect(restored.items.first.name, comanda.items.first.name);
      expect(restored.timestamp, comanda.timestamp);
    });
  });
}
