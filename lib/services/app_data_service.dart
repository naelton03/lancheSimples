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

  static const String defaultDraftIdentifier = 'COMANDA EM ABERTO';

  final FirebaseFirestore? _firestore;
  final MockDataService _mockDataService;
  final StreamController<int> _localDraftController =
      StreamController<int>.broadcast();
  final StreamController<int> _localCatalogController =
      StreamController<int>.broadcast();
  final Map<String, Comanda> _localComandas = <String, Comanda>{};
  final Map<String, List<Item>> _catalogCacheByTenant = <String, List<Item>>{};

  bool get isRemoteEnabled => _firestore != null;

  void dispose() {
    _localDraftController.close();
    _localCatalogController.close();
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
      return _localCatalogController.stream.startWith(0).map(
            (_) => _mockDataService.getCatalogForTenant(normalizedTenantId),
          );
    }

    return _watchRemoteCatalog(normalizedTenantId);
  }

  Future<Item> createCatalogItem({
    required String tenantId,
    required String name,
    required double price,
    required String category,
    required String createdBy,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    final normalizedName = name.trim();
    final normalizedCategory = category.trim().isEmpty ? 'Geral' : category.trim();
    final newItem = Item(
      id: _catalogItemId(normalizedName),
      tenantId: normalizedTenantId,
      name: normalizedName,
      price: price,
      category: normalizedCategory,
      createdBy: createdBy.trim().isEmpty ? 'Operador' : createdBy.trim(),
      createdAt: DateTime.now().toUtc(),
    );

    if (_firestore == null) {
      final createdItem = _mockDataService.createCatalogItem(newItem);
      _catalogCacheByTenant[normalizedTenantId] =
          _buildSortedCatalog(_mockDataService.getCatalogForTenant(normalizedTenantId));
      _localCatalogController.add(createdItem.hashCode);
      return createdItem;
    }

    await _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('catalog')
        .doc(newItem.id)
        .set(newItem.toMap());
    final cachedCatalog = _catalogCacheByTenant[normalizedTenantId] ??
        _mockDataService.getCatalogForTenant(normalizedTenantId);
    _catalogCacheByTenant[normalizedTenantId] = _buildSortedCatalog(
      <Item>[
        ...cachedCatalog.where((item) => item.id != newItem.id),
        newItem,
      ],
    );
    return newItem;
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
      final seededItem = item.copyWith(
        createdBy: createdBy,
        createdAt: DateTime.now().toUtc(),
      );
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
        _createDraftComanda(
          tenantId: '',
          operatorName: operatorName,
        ),
      );
    }

    if (_firestore == null) {
      return _localDraftController.stream.startWith(0).map(
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
        return _createDraftComanda(
          tenantId: normalizedTenantId,
          operatorName: operatorName,
        );
      }

      return Comanda.fromMap(snapshot.data()!);
    });
  }

  Future<void> updateDraftComandaIdentifier({
    required String tenantId,
    required String operatorName,
    required String identifier,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return;
    }

    final sanitizedIdentifier = _sanitizeDraftIdentifier(identifier);
    if (_firestore == null) {
      final current = _buildLocalDraftComanda(normalizedTenantId, operatorName);
      _localComandas[_localDraftKey(normalizedTenantId, operatorName)] =
          current.copyWith(
        identifier: sanitizedIdentifier,
        timestamp: DateTime.now(),
      );
      _localDraftController.add(sanitizedIdentifier.length);
      return;
    }

    final current = await _getOrCreateRemoteDraft(normalizedTenantId, operatorName);
    final updatedDraft = current.copyWith(
      identifier: sanitizedIdentifier,
      timestamp: DateTime.now().toUtc(),
    );

    await _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(_draftComandaId(operatorName))
        .set(updatedDraft.toMap());
  }

  Future<Comanda> addItemToDraftComanda({
    required String tenantId,
    required String operatorName,
    required Item item,
    String? draftIdentifier,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return _buildLocalDraftComanda(normalizedTenantId, operatorName);
    }

    final persistedItem = item.copyWith(
      tenantId: normalizedTenantId,
      createdBy: operatorName,
      createdAt: item.createdAt ?? DateTime.now().toUtc(),
      notes: item.notes?.trim().isEmpty == true ? null : item.notes?.trim(),
    );

    if (_firestore == null) {
      final draft = _buildLocalDraftComanda(normalizedTenantId, operatorName);
      final updatedItems = <Item>[...draft.items, persistedItem];
      final updatedDraft = draft.copyWith(
        identifier: _sanitizeDraftIdentifier(draftIdentifier ?? draft.identifier),
        items: updatedItems,
        totalAmount: updatedItems.fold<double>(
          0,
          (runningTotal, entry) => runningTotal + entry.price,
        ),
        timestamp: DateTime.now(),
      );
      _localComandas[_localDraftKey(normalizedTenantId, operatorName)] =
          updatedDraft;
      _localDraftController.add(updatedItems.length);
      return updatedDraft;
    }

    final current = await _getOrCreateRemoteDraft(normalizedTenantId, operatorName);
    final updatedItems = <Item>[...current.items, persistedItem];
    final updatedComanda = current.copyWith(
      identifier: _sanitizeDraftIdentifier(draftIdentifier ?? current.identifier),
      items: updatedItems,
      totalAmount: updatedItems.fold<double>(
        0,
        (runningTotal, entry) => runningTotal + entry.price,
      ),
      timestamp: DateTime.now().toUtc(),
    );

    await _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(_draftComandaId(operatorName))
        .set(updatedComanda.toMap());
    return updatedComanda;
  }

  Future<Comanda> addItemToComanda({
    required String tenantId,
    required String comandaId,
    required String operatorName,
    required Item item,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return _createDraftComanda(
        tenantId: '',
        operatorName: operatorName,
      );
    }

    final persistedItem = item.copyWith(
      tenantId: normalizedTenantId,
      createdBy: operatorName.trim().isEmpty ? 'Operador' : operatorName.trim(),
      createdAt: item.createdAt ?? DateTime.now().toUtc(),
      notes: item.notes?.trim().isEmpty == true ? null : item.notes?.trim(),
    );

    if (_firestore == null) {
      final key = _localComandaKey(normalizedTenantId, comandaId);
      final current = _localComandas[key];
      if (current == null) {
        throw StateError('Comanda não encontrada.');
      }

      final updatedItems = <Item>[...current.items, persistedItem];
      final updatedComanda = current.copyWith(
        items: updatedItems,
        totalAmount: updatedItems.fold<double>(
          0,
          (runningTotal, entry) => runningTotal + entry.price,
        ),
        timestamp: DateTime.now(),
      );
      _localComandas[key] = updatedComanda;
      _localDraftController.add(updatedComanda.items.length);
      return updatedComanda;
    }

    final comandaRef = _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(comandaId);

    final snapshot = await comandaRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Comanda não encontrada.');
    }

    final current = Comanda.fromMap(snapshot.data()!);
    final updatedItems = <Item>[...current.items, persistedItem];
    final updatedComanda = current.copyWith(
      items: updatedItems,
      totalAmount: updatedItems.fold<double>(
        0,
        (runningTotal, entry) => runningTotal + entry.price,
      ),
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
      _localDraftController.add(0);
      return;
    }

    await _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(_draftComandaId(operatorName))
        .delete();
  }

  Stream<List<Comanda>> watchComandas({
    required String tenantId,
    String filter = 'all',
  }) {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return Stream<List<Comanda>>.value(const <Comanda>[]);
    }

    if (_firestore == null) {
      return _localDraftController.stream.startWith(0).map(
            (_) => _listLocalComandas(
              tenantId: normalizedTenantId,
              filter: filter,
            ),
          );
    }

    return _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Comanda.fromMap(doc.data()))
              .where(_isMeaningfulComanda)
              .where((comanda) => _matchesComandaFilter(comanda, filter))
              .toList(growable: false),
        );
  }

  Future<Comanda> createComanda({
    required String tenantId,
    required String operatorName,
    String? customerName,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return _createDraftComanda(
        tenantId: '',
        operatorName: operatorName,
      );
    }

    final identifier = await _nextComandaIdentifier(normalizedTenantId);
    final comanda = Comanda(
      id: _comandaId(identifier),
      tenantId: normalizedTenantId,
      identifier: identifier,
      customerName: customerName?.trim().isEmpty == true
          ? null
          : customerName?.trim(),
      items: const <Item>[],
      createdBy: operatorName,
      timestamp: DateTime.now().toUtc(),
      status: 'open',
      totalAmount: 0,
    );

    if (_firestore == null) {
      _localComandas[_localComandaKey(normalizedTenantId, comanda.id)] = comanda;
      _localDraftController.add(_localComandas.length);
      return comanda;
    }

    await _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(comanda.id)
        .set(comanda.toMap());
    return comanda;
  }

  Future<void> closeComanda({
    required String tenantId,
    required String comandaId,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return;
    }

    if (_firestore == null) {
      final key = _localComandaKey(normalizedTenantId, comandaId);
      final comanda = _localComandas[key];
      if (comanda == null) {
        return;
      }
      _localComandas[key] = comanda.copyWith(
        status: 'closed',
        timestamp: DateTime.now(),
      );
      _localDraftController.add(comanda.totalAmount.round());
      return;
    }

    final docRef = _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(comandaId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final comanda = Comanda.fromMap(snapshot.data()!);
    await docRef.set(
      comanda.copyWith(
        status: 'closed',
        timestamp: DateTime.now().toUtc(),
      ).toMap(),
    );
  }

  Future<void> removeItemFromComanda({
    required String tenantId,
    required String comandaId,
    required int itemIndex,
  }) async {
    final normalizedTenantId = tenantId.trim().toUpperCase();
    if (normalizedTenantId.isEmpty) {
      return;
    }

    if (_firestore == null) {
      final key = _localComandaKey(normalizedTenantId, comandaId);
      final comanda = _localComandas[key];
      if (comanda == null || itemIndex < 0 || itemIndex >= comanda.items.length) {
        return;
      }

      final updatedItems = <Item>[...comanda.items]..removeAt(itemIndex);
      _localComandas[key] = comanda.copyWith(
        items: updatedItems,
        totalAmount: updatedItems.fold<double>(
          0,
          (runningTotal, entry) => runningTotal + entry.price,
        ),
        timestamp: DateTime.now(),
      );
      _localDraftController.add(updatedItems.length);
      return;
    }

    final docRef = _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .collection('comandas')
        .doc(comandaId);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final comanda = Comanda.fromMap(snapshot.data()!);
    if (itemIndex < 0 || itemIndex >= comanda.items.length) {
      return;
    }

    final updatedItems = <Item>[...comanda.items]..removeAt(itemIndex);
    await docRef.set(
      comanda.copyWith(
        items: updatedItems,
        totalAmount: updatedItems.fold<double>(
          0,
          (runningTotal, entry) => runningTotal + entry.price,
        ),
        timestamp: DateTime.now().toUtc(),
      ).toMap(),
    );
  }

  List<String> getCategoriesForItems(List<Item> items) {
    return _mockDataService.getCategoriesForItems(items);
  }

  Stream<List<Item>> _watchRemoteCatalog(String tenantId) async* {
    try {
      await for (final snapshot in _firestore!
          .collection('tenants')
          .doc(tenantId)
          .collection('catalog')
          .orderBy('category')
          .orderBy('name')
          .snapshots()) {
        final items = snapshot.docs
            .map(
              (doc) => Item.fromMap(
                <String, dynamic>{
                  ...doc.data(),
                  'id': doc.id,
                  'tenantId': tenantId,
                },
              ),
            )
            .toList(growable: false);

        if (items.isNotEmpty) {
          final sortedItems = _buildSortedCatalog(items);
          _catalogCacheByTenant[tenantId] = sortedItems;
          yield sortedItems;
          continue;
        }

        try {
          await seedCatalogIfNeeded(tenantId, createdBy: 'Sistema');
        } catch (_) {
          // Cai no fallback local logo abaixo.
        }

        yield _catalogCacheByTenant[tenantId] ??
            _buildSortedCatalog(_mockDataService.getCatalogForTenant(tenantId));
      }
    } catch (_) {
      yield _catalogCacheByTenant[tenantId] ??
          _buildSortedCatalog(_mockDataService.getCatalogForTenant(tenantId));
    }
  }

  List<Item> _buildSortedCatalog(List<Item> items) {
    final catalog = List<Item>.from(items)
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

  List<Comanda> _listLocalComandas({
    required String tenantId,
    required String filter,
  }) {
    final comandas = _localComandas.values
        .where((comanda) => comanda.tenantId == tenantId)
        .where(_isMeaningfulComanda)
        .where((comanda) => _matchesComandaFilter(comanda, filter))
        .toList(growable: false)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return comandas;
  }

  bool _matchesComandaFilter(Comanda comanda, String filter) {
    if (filter == 'open') {
      return comanda.status == 'open';
    }
    if (filter == 'closed') {
      return comanda.status == 'closed';
    }
    return true;
  }

  bool _isMeaningfulComanda(Comanda comanda) {
    return comanda.items.isNotEmpty ||
        comanda.customerName?.trim().isNotEmpty == true ||
        comanda.identifier != defaultDraftIdentifier ||
        comanda.status == 'closed';
  }

  Future<String> _nextComandaIdentifier(String tenantId) async {
    if (_firestore == null) {
      final existing = _listLocalComandas(tenantId: tenantId, filter: 'all');
      return _formatComandaIdentifier(existing.length + 1);
    }

    final snapshot = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('comandas')
        .get();
    return _formatComandaIdentifier(snapshot.docs.length + 1);
  }

  String _formatComandaIdentifier(int index) => '#${index.toString().padLeft(3, '0')}';

  String _comandaId(String identifier) {
    return 'comanda-${identifier.replaceAll('#', '').toLowerCase()}';
  }

  Future<Comanda> _getOrCreateRemoteDraft(
    String tenantId,
    String operatorName,
  ) async {
    final comandaRef = _firestore!
        .collection('tenants')
        .doc(tenantId)
        .collection('comandas')
        .doc(_draftComandaId(operatorName));
    final existing = await comandaRef.get();

    if (existing.exists && existing.data() != null) {
      return Comanda.fromMap(existing.data()!);
    }

    return _createDraftComanda(
      tenantId: tenantId,
      operatorName: operatorName,
    );
  }

  Comanda _buildLocalDraftComanda(String tenantId, String operatorName) {
    return _localComandas[_localDraftKey(tenantId, operatorName)] ??
        _createDraftComanda(
          tenantId: tenantId,
          operatorName: operatorName,
        );
  }

  Comanda _createDraftComanda({
    required String tenantId,
    required String operatorName,
    String? identifier,
    List<Item> items = const <Item>[],
  }) {
    return Comanda(
      id: _draftComandaId(operatorName),
      tenantId: tenantId,
      identifier: _sanitizeDraftIdentifier(identifier),
      items: items,
      createdBy: operatorName,
      timestamp: DateTime.now(),
      status: 'open',
      totalAmount: items.fold<double>(
        0,
        (runningTotal, entry) => runningTotal + entry.price,
      ),
    );
  }

  String _sanitizeDraftIdentifier(String? identifier) {
    final normalizedIdentifier = identifier?.trim() ?? '';
    if (normalizedIdentifier.isEmpty) {
      return defaultDraftIdentifier;
    }
    return normalizedIdentifier;
  }

  String _catalogItemId(String name) {
    final normalizedName = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${normalizedName.isEmpty ? 'item' : normalizedName}-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _localDraftKey(String tenantId, String operatorName) {
    return '$tenantId::${_draftComandaId(operatorName)}';
  }

  String _localComandaKey(String tenantId, String comandaId) {
    return '$tenantId::$comandaId';
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
