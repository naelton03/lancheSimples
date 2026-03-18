import 'package:flutter/material.dart';

import '../models/comanda.dart';
import '../models/firebase_initialization_state.dart';
import '../models/item.dart';
import '../services/app_data_service.dart';
import '../services/local_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dataService,
    required this.storageService,
    required this.firebaseState,
    required this.onResetDevice,
  });

  final AppDataService dataService;
  final LocalStorageService storageService;
  final FirebaseInitializationState firebaseState;
  final VoidCallback onResetDevice;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'Todos';
  String employeeName = 'Operador';
  String tenantId = '';
  late Future<void> loadFuture;

  @override
  void initState() {
    super.initState();
    loadFuture = _loadOperator();
  }

  Future<void> _loadOperator() async {
    final storedName = await widget.storageService.getEmployeeName();
    final storedTenantId = await widget.storageService.getTenantId();
    if (!mounted) {
      return;
    }

    setState(() {
      employeeName =
          storedName?.trim().isNotEmpty == true ? storedName!.trim() : 'Operador';
      tenantId = storedTenantId?.trim().toUpperCase() ?? '';
    });

    if (tenantId.isNotEmpty) {
      await widget.dataService.seedCatalogIfNeeded(tenantId, createdBy: employeeName);
    }
  }

  Future<void> _addItem(Item item, Comanda comanda) async {
    final notesController = TextEditingController();
    final shouldAddItem = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adicione uma observação opcional para este lançamento.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observação do item',
                        hintText: 'Ex.: sem cebola, ponto da carne, retirar gelo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Adicionar à comanda'),
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;

    final notes = notesController.text.trim();
    notesController.dispose();

    if (!shouldAddItem) {
      return;
    }

    try {
      await widget.dataService.addItemToDraftComanda(
        tenantId: tenantId,
        operatorName: employeeName,
        draftIdentifier: comanda.identifier,
        item: item.copyWith(notes: notes.isEmpty ? null : notes),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} adicionado à comanda.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao adicionar item: $error')),
      );
    }
  }

  Future<void> _resetDevice() async {
    await widget.storageService.clearOnboarding();
    widget.onResetDevice();
  }

  Future<void> _clearCurrentDraft() async {
    await widget.dataService.clearDraftComanda(
      tenantId: tenantId,
      operatorName: employeeName,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _editDraftIdentifier(Comanda comanda) async {
    final identifierController = TextEditingController(
      text: comanda.identifier == AppDataService.defaultDraftIdentifier
          ? ''
          : comanda.identifier,
    );

    final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Abrir / identificar comanda'),
              content: TextField(
                controller: identifierController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Mesa ou cliente',
                  hintText: 'Ex.: Mesa 7 ou Ana Paula',
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        ) ??
        false;

    final identifier = identifierController.text.trim();
    identifierController.dispose();

    if (!shouldSave) {
      return;
    }

    await widget.dataService.updateDraftComandaIdentifier(
      tenantId: tenantId,
      operatorName: employeeName,
      identifier: identifier,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          identifier.isEmpty
              ? 'Comanda voltou ao estado padrão.'
              : 'Comanda identificada como $identifier.',
        ),
      ),
    );
  }

  Future<void> _openCatalogCreationDialog({required bool isCombo}) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController(
      text: isCombo ? 'Combos' : 'Lanches',
    );

    final shouldCreate = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(isCombo ? 'Cadastrar combo' : 'Cadastrar item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: isCombo ? 'Nome do combo' : 'Nome do item',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Preço',
                        hintText: 'Ex.: 19,90',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        hintText: 'Ex.: Lanches, Bebidas, Combos',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isCombo
                          ? 'Use esta opção para cadastrar ofertas promocionais como um item de catálogo do tipo combo.'
                          : 'Cadastre itens rápidos com nome, preço, categoria e autoria do operador.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldCreate) {
      nameController.dispose();
      priceController.dispose();
      categoryController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final rawPrice = priceController.text.trim().replaceAll(',', '.');
    final category = categoryController.text.trim();
    final price = double.tryParse(rawPrice);
    nameController.dispose();
    priceController.dispose();
    categoryController.dispose();

    if (!mounted) {
      return;
    }

    if (name.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe nome e preço válido para cadastrar no catálogo.'),
        ),
      );
      return;
    }

    try {
      final item = await widget.dataService.createCatalogItem(
        tenantId: tenantId,
        name: name,
        price: price,
        category: category,
        createdBy: employeeName,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} cadastrado no catálogo.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao cadastrar item: $error')),
      );
    }
  }

  void _showSummary(Comanda comanda) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Resumo da comanda',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  comanda.items.isEmpty
                      ? 'Nenhum item adicionado ainda.'
                      : '${comanda.identifier} • ${comanda.items.length} itens',
                  style: const TextStyle(color: AppTheme.subtitle),
                ),
                const SizedBox(height: 16),
                if (comanda.items.isEmpty)
                  const Text('Adicione itens para iniciar o atendimento.')
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: comanda.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final item = comanda.items[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: AppTheme.title,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lançado por ${item.createdBy}',
                                    style: const TextStyle(
                                      color: AppTheme.subtitle,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (item.notes?.trim().isNotEmpty == true) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Obs.: ${item.notes!.trim()}',
                                      style: const TextStyle(
                                        color: AppTheme.subtitle,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              'R\$ ${item.price.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(color: AppTheme.subtitle),
                      ),
                    ),
                    Text(
                      'R\$ ${comanda.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(
                        color: AppTheme.title,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                if (comanda.items.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _clearCurrentDraft,
                    child: const Text('Limpar comanda atual'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<List<Item>>(
          stream: widget.dataService.watchCatalog(tenantId),
          builder: (context, itemsSnapshot) {
            final allItems = itemsSnapshot.data ?? const <Item>[];
            final categories = widget.dataService.getCategoriesForItems(allItems);
            final effectiveSelectedCategory = categories.contains(selectedCategory)
                ? selectedCategory
                : 'Todos';
            final filteredItems = effectiveSelectedCategory == 'Todos'
                ? allItems
                : allItems
                    .where((item) => item.category == effectiveSelectedCategory)
                    .toList(growable: false);

            return StreamBuilder<Comanda>(
              stream: widget.dataService.watchDraftComanda(
                tenantId: tenantId,
                operatorName: employeeName,
              ),
              builder: (context, comandaSnapshot) {
                final comanda = comandaSnapshot.data ??
                    Comanda(
                      id: 'draft-$employeeName',
                      tenantId: tenantId,
                      identifier: AppDataService.defaultDraftIdentifier,
                      items: const <Item>[],
                      createdBy: employeeName,
                      timestamp: DateTime.now(),
                      status: 'open',
                      totalAmount: 0,
                    );

                return Scaffold(
                  appBar: AppBar(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('LancheSimples'),
                        if (tenantId.isNotEmpty)
                          Text(
                            tenantId,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    actions: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          child: Text(
                            employeeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.subtitle,
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'reset') {
                            await _resetDevice();
                          }
                          if (value == 'new_item') {
                            await _openCatalogCreationDialog(isCombo: false);
                          }
                          if (value == 'new_combo') {
                            await _openCatalogCreationDialog(isCombo: true);
                          }
                        },
                        itemBuilder: (context) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'new_item',
                            child: Text('Cadastrar item'),
                          ),
                          PopupMenuItem<String>(
                            value: 'new_combo',
                            child: Text('Cadastrar combo'),
                          ),
                          PopupMenuItem<String>(
                            value: 'reset',
                            child: Text('Refazer onboarding'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.dataService.isRemoteEnabled
                              ? const Color(0xFFF0FFF4)
                              : const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.dataService.isRemoteEnabled
                                ? const Color(0xFFC6F6D5)
                                : const Color(0xFFFFD7D9),
                          ),
                        ),
                        child: Text(
                          widget.firebaseState.message,
                          style: const TextStyle(color: AppTheme.subtitle),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F1F1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Comanda atual',
                              style: TextStyle(
                                color: AppTheme.subtitle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              comanda.identifier,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Abra a comanda com mesa ou nome do cliente para não misturar atendimento.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => _editDraftIdentifier(comanda),
                              child: const Text('Identificar comanda'),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          'Categorias',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.title,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: categories.map((category) {
                            final selected = category == effectiveSelectedCategory;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: selected,
                                showCheckmark: false,
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : AppTheme.title,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    selectedCategory = category;
                                  });
                                },
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      Expanded(
                        child: filteredItems.isEmpty
                            ? const Center(
                                child: Text('Nenhum item cadastrado para este tenant.'),
                              )
                            : ListView.builder(
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  return ItemCard(
                                    item: item,
                                    onAdd: () => _addItem(item, comanda),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  bottomNavigationBar: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFEFEFEF))),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  comanda.identifier,
                                  style: const TextStyle(color: AppTheme.subtitle),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'R\$ ${comanda.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.title,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showSummary(comanda),
                            child: Text(
                              comanda.items.isEmpty
                                  ? 'Resumo'
                                  : 'Resumo (${comanda.items.length})',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
