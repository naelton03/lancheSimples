import 'package:flutter_test/flutter_test.dart';
import 'package:lanche_simples/models/comanda.dart';
import 'package:lanche_simples/models/item.dart';
import 'package:lanche_simples/models/tenant.dart';

void main() {
  group('model serialization', () {
    test('Tenant serializes and deserializes correctly', () {
      final tenant = Tenant(
        name: 'Lanche Central',
        tenantId: 'TENANT-1001',
        createdAt: DateTime.parse('2026-03-18T12:00:00.000Z'),
      );

      final map = tenant.toMap();
      final restored = Tenant.fromMap(map);

      expect(restored.name, tenant.name);
      expect(restored.tenantId, tenant.tenantId);
      expect(restored.createdAt, tenant.createdAt);
    });

    test('Item serializes and deserializes correctly', () {
      final item = Item(
        id: 'x-burger',
        tenantId: 'TENANT-1001',
        name: 'X-Burger',
        price: 15.5,
        category: 'Lanches',
        createdBy: 'Maria',
        notes: 'Sem cebola',
        createdAt: DateTime.parse('2026-03-18T12:00:00.000Z'),
      );

      final map = item.toMap();
      final restored = Item.fromMap(map);

      expect(restored.id, item.id);
      expect(restored.tenantId, item.tenantId);
      expect(restored.name, item.name);
      expect(restored.price, item.price);
      expect(restored.category, item.category);
      expect(restored.createdBy, item.createdBy);
      expect(restored.notes, item.notes);
      expect(restored.createdAt, item.createdAt);
    });

    test('Comanda serializes and deserializes correctly', () {
      final comanda = Comanda(
        id: 'mesa-10',
        tenantId: 'TENANT-1001',
        identifier: 'Mesa 10',
        items: <Item>[
          Item(
            id: 'batata-g',
            tenantId: 'TENANT-1001',
            name: 'Batata G',
            price: 12,
            category: 'Acompanhamentos',
            createdBy: 'João',
            createdAt: DateTime.parse('2026-03-18T12:00:00.000Z'),
          ),
        ],
        createdBy: 'João',
        timestamp: DateTime.parse('2026-03-18T12:00:00.000Z'),
        status: 'open',
        totalAmount: 12,
      );

      final map = comanda.toMap();
      final restored = Comanda.fromMap(map);

      expect(restored.id, comanda.id);
      expect(restored.tenantId, comanda.tenantId);
      expect(restored.identifier, comanda.identifier);
      expect(restored.createdBy, comanda.createdBy);
      expect(restored.items.first.name, comanda.items.first.name);
      expect(restored.timestamp, comanda.timestamp);
      expect(restored.status, comanda.status);
      expect(restored.totalAmount, comanda.totalAmount);
    });
  });
}
