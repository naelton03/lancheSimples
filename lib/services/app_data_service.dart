import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/comanda.dart';
import '../models/item.dart';
import '../models/tenant.dart';
import 'mock_data_service.dart';

class AppDataService {
  AppDataService({
    FirebaseFirestore? firestore,
    MockDataService? mockDataService,
  })  : _firestore = firestore,
        _mockDataService = mockDataService ?? MockDataService();

  final FirebaseFirestore? _firestore;
  final MockDataService _mockDataService;
  final StreamController<int> _localComandasController =
      StreamController<int>.broadcast();
  final Map<String, List<Item>> _localComandas = <String, List<Item>>{};

  bool get isRemoteEnabled => _firestore != null;

  void dispose() {
    _localComandasController.close();
  }

  Future<List<Tenant>> getTenants() async {
    if (_firestore == null) {
      return _mockDataService.getTenants();
    }

    final snapshot = await _firestore
        .collection('tenants')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Tenant.fromMap(doc.data()))
        .toList(growable: false);
  }

  Future<Tenant?> getTenantById(String tenantId) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (_firestore == null) {
      return _mockDataService.getTenantById(normalizedTenantId);
    }

    final doc = await _firestore.collection('tenants').doc(normalizedTenantId).get();
    if (!doc.exists) {
      return null;
    }

    return Tenant.fromMap(doc.data()!);
  }

  Future<bool> isValidTenant(String tenantId) async {
    return (await getTenantById(tenantId)) != null;
  }

  Future<Tenant> createTenant(String name) async {
    if (_firestore == null) {
      return _mockDataService.createTenant(name);
    }

    final normalizedName = name.trim();
    final existingTenants = await getTenants();
    for (final tenant in existingTenants) {
      if (tenant.name.toLowerCase() == normalizedName.toLowerCase()) {
        await seedCatalogIfNeeded(tenant.tenantId, createdBy: 'Master Admin');
        return tenant;
      }
    }

    var maxCode = 1000;
    for (final tenant in existingTenants) {
      final match = RegExp(r'^TENANT-(\d+)$').firstMatch(tenant.tenantId);
      final code = int.tryParse(match?.group(1) ?? '');
      if (code != null && code > maxCode) {
        maxCode = code;
      }
    }

    final tenant = Tenant(
      name: normalizedName,
      tenantId: 'TENANT-${maxCode + 1}',
      createdAt: DateTime.now().toUtc(),
    );

    await _firestore.collection('tenants').doc(tenant.tenantId).set(tenant.toMap());
    await seedCatalogIfNeeded(tenant.tenantId, createdBy: 'Master Admin');
    return tenant;
  }

  Stream<List<Item>> watchCatalog(String tenantId) {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return Stream<List<Item>>.value(const <Item>[]);
    }

    if (_firestore == null) {
      return Stream<List<Item>>.value(
        _mockDataService.getCatalogForTenant(normalizedTenantId),
      );
    }

    final stream = _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('catalog')
        .orderBy('category')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(
              (doc) => Item.fromMap(
                <String, dynamic>{
                  ...doc.data(),
                  'id': doc.id,
                  'tenantId': normalizedTenantId,
                },
              ),
            )
            .toList(growable: false));

    return stream.asyncMap((items) async {
      if (items.isNotEmpty) {
        return items;
      }

      await seedCatalogIfNeeded(normalizedTenantId, createdBy: 'Sistema');
      return _mockDataService.getCatalogForTenant(normalizedTenantId);
    });
  }

  Future<void> seedCatalogIfNeeded(String tenantId, {required String createdBy}) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty || _firestore == null) {
      return;
    }

    final catalogCollection = _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('catalog');

    final existing = await catalogCollection.limit(1).get();
    if (existing.docs.isNotEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final item in _mockDataService.getCatalogForTenant(normalizedTenantId)) {
      final seededItem = item.copyWith(createdBy: createdBy, createdAt: DateTime.now().toUtc());
      batch.set(catalogCollection.doc(seededItem.id), seededItem.toMap());
    }
    await batch.commit();
  }

  Stream<Comanda> watchDraftComanda({
    required String tenantId,
    required String operatorName,
  }) {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return Stream<Comanda>.value(
        Comanda(
          id: _draftComandaId(operatorName),
          tenantId: '',
          identifier: 'COMANDA EM ABERTO',
          items: const <Item>[],
          createdBy: operatorName,
          timestamp: DateTime.now(),
          status: 'open',
          totalAmount: 0,
        ),
      );
    }

    if (_firestore == null) {
      return _localComandasController.stream.startWith(0).map(
            (_) => _buildLocalDraftComanda(normalizedTenantId, operatorName),
          );
    }

    return _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(_draftComandaId(operatorName))
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return Comanda(
          id: _draftComandaId(operatorName),
          tenantId: normalizedTenantId,
          identifier: 'COMANDA EM ABERTO',
          items: const <Item>[],
          createdBy: operatorName,
          timestamp: DateTime.now(),
          status: 'open',
          totalAmount: 0,
        );
      }

      return Comanda.fromMap(snapshot.data()!);
    });
  }

  Future<Comanda> addItemToDraftComanda({
    required String tenantId,
    required String operatorName,
    required Item item,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return _buildLocalDraftComanda(normalizedTenantId, operatorName);
    }

    if (_firestore == null) {
      final draft = _buildLocalDraftComanda(normalizedTenantId, operatorName);
      final updatedItems = <Item>[
        ...draft.items,
        item.copyWith(tenantId: normalizedTenantId),
      ];
      _localComandas[_localDraftKey(normalizedTenantId, operatorName)] =
          updatedItems;
      _localComandasController.add(updatedItems.length);
      return _buildLocalDraftComanda(normalizedTenantId, operatorName);
    }

    final comandaRef = _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(_draftComandaId(operatorName));

    final existing = await comandaRef.get();
    final current = existing.exists && existing.data() != null
        ? Comanda.fromMap(existing.data()!)
        : Comanda(
            id: _draftComandaId(operatorName),
            tenantId: normalizedTenantId,
            identifier: 'COMANDA EM ABERTO',
            items: const <Item>[],
            createdBy: operatorName,
            timestamp: DateTime.now().toUtc(),
            status: 'open',
            totalAmount: 0,
          );

    final persistedItem = item.copyWith(
      tenantId: normalizedTenantId,
      createdAt: item.createdAt ?? DateTime.now().toUtc(),
    );
    final updatedItems = <Item>[...current.items, persistedItem];
    final updatedComanda = current.copyWith(
      items: updatedItems,
      totalAmount: updatedItems.fold<double>(0, (runningTotal, entry) => runningTotal + entry.price),
      timestamp: DateTime.now().toUtc(),
    );

    await comandaRef.set(updatedComanda.toMap());
    return updatedComanda;
  }

  Future<void> clearDraftComanda({
    required String tenantId,
    required String operatorName,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return;
    }

    if (_firestore == null) {
      _localComandas.remove(_localDraftKey(normalizedTenantId, operatorName));
      _localComandasController.add(0);
      return;
    }

    await _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(_draftComandaId(operatorName))
        .delete();
  }

  List<String> getCategoriesForItems(List<Item> items) {
    return _mockDataService.getCategoriesForItems(items);
  }

  Comanda _buildLocalDraftComanda(String tenantId, String operatorName) {
    final items = List<Item>.unmodifiable(
      _localComandas[_localDraftKey(tenantId, operatorName)] ?? const <Item>[],
    );
    return Comanda(
      id: _draftComandaId(operatorName),
      tenantId: tenantId,
      identifier: 'COMANDA EM ABERTO',
      items: items,
      createdBy: operatorName,
      timestamp: DateTime.now(),
      status: 'open',
      totalAmount: items.fold<double>(0, (runningTotal, entry) => runningTotal + entry.price),
    );
  }

  String _localDraftKey(String tenantId, String operatorName) {
    return '$tenantId::${_draftComandaId(operatorName)}';
  }

  String _draftComandaId(String operatorName) {
    final normalizedOperator = operatorName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalizedOperator.isEmpty ? 'draft-device' : 'draft-$normalizedOperator';
  }
}

extension<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
