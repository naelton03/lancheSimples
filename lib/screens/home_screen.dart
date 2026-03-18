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
  int selectedHomeSection = 0;
  String comandaFilter = 'open';
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

  Future<void> _openCreateComandaDialog() async {
    final customerController = TextEditingController();
    final shouldCreate = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Nova comanda'),
              content: TextField(
                controller: customerController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Cliente (opcional)',
                  hintText: 'Ex.: João Silva',
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Criar'),
                ),
              ],
            );
          },
        ) ??
        false;

    final customerName = customerController.text.trim();
    customerController.dispose();

    if (!shouldCreate || !mounted) {
      return;
    }

    final comanda = await widget.dataService.createComanda(
      tenantId: tenantId,
      operatorName: employeeName,
      customerName: customerName.isEmpty ? null : customerName,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Comanda ${comanda.identifier} criada com sucesso.')),
    );
  }

  Future<void> _closeComanda(Comanda comanda) async {
    await widget.dataService.closeComanda(
      tenantId: tenantId,
      comandaId: comanda.id,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Comanda ${comanda.identifier} fechada.')),
    );
  }

  void _showOpenComandaDetails(Comanda comanda) {
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
                  'Comanda ${comanda.identifier}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  comanda.customerName?.trim().isNotEmpty == true
                      ? 'Cliente: ${comanda.customerName}'
                      : 'Cliente não informado',
                  style: const TextStyle(color: AppTheme.subtitle),
                ),
                const SizedBox(height: 16),
                if (comanda.items.isEmpty)
                  const Text('Nenhum item lançado nesta comanda até o momento.')
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
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.title,
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
                                ],
                              ),
                            ),
                            Text(
                              'R\$ ${item.price.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (comanda.status == 'open') ...<Widget>[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await widget.dataService.removeItemFromComanda(
                                    tenantId: tenantId,
                                    comandaId: comanda.id,
                                    itemIndex: index,
                                  );
                                  if (!mounted || !context.mounted) {
                                    return;
                                  }
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Item removido da comanda.'),
                                    ),
                                  );
                                },
                              ),
                            ],
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
                        fontWeight: FontWeight.w700,
                        color: AppTheme.title,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
            final isCatalogLoading =
                itemsSnapshot.connectionState == ConnectionState.waiting &&
                    !itemsSnapshot.hasData;
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: <Widget>[
                            ChoiceChip(
                              label: const Text('Catálogo'),
                              selected: selectedHomeSection == 0,
                              showCheckmark: false,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: selectedHomeSection == 0
                                    ? Colors.white
                                    : AppTheme.title,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  selectedHomeSection = 0;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Comandas'),
                              selected: selectedHomeSection == 1,
                              showCheckmark: false,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: selectedHomeSection == 1
                                    ? Colors.white
                                    : AppTheme.title,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  selectedHomeSection = 1;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: selectedHomeSection == 0
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                        final selected =
                                            category == effectiveSelectedCategory;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: Text(category),
                                            selected: selected,
                                            showCheckmark: false,
                                            selectedColor: AppTheme.primary,
                                            labelStyle: TextStyle(
                                              color: selected
                                                  ? Colors.white
                                                  : AppTheme.title,
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
                                    child: isCatalogLoading
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : filteredItems.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'Nenhum item cadastrado para este tenant.',
                                            ),
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
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            'Comandas Abertas',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.tune_rounded,
                                          color: AppTheme.subtitle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    child: Text(
                                      'Acompanhe, filtre e finalize comandas em andamento.',
                                      style: TextStyle(color: AppTheme.subtitle),
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        for (final filter in <String, String>{
                                          'all': 'Todas',
                                          'open': 'Abertas',
                                          'closed': 'Fechadas',
                                        }.entries)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                              label: Text(filter.value),
                                              selected: comandaFilter == filter.key,
                                              showCheckmark: false,
                                              selectedColor: AppTheme.primary,
                                              labelStyle: TextStyle(
                                                color: comandaFilter == filter.key
                                                    ? Colors.white
                                                    : AppTheme.title,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              onSelected: (_) {
                                                setState(() {
                                                  comandaFilter = filter.key;
                                                });
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: StreamBuilder<List<Comanda>>(
                                      stream: widget.dataService.watchComandas(
                                        tenantId: tenantId,
                                        filter: comandaFilter,
                                      ),
                                      builder: (context, comandasSnapshot) {
                                        final comandas =
                                            comandasSnapshot.data ?? const <Comanda>[];
                                        if (comandasSnapshot.connectionState ==
                                                ConnectionState.waiting &&
                                            !comandasSnapshot.hasData) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }

                                        if (comandas.isEmpty) {
                                          return const Center(
                                            child: Text(
                                              'Nenhuma comanda encontrada para este filtro.',
                                            ),
                                          );
                                        }

                                        return ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            24,
                                          ),
                                          itemCount: comandas.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final listedComanda = comandas[index];
                                            final previewItems = listedComanda.items
                                                .take(2)
                                                .toList(growable: false);
                                            final statusLabel =
                                                listedComanda.status == 'closed'
                                                    ? 'Fechada'
                                                    : 'Aberta';
                                            return Card(
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Row(
                                                      children: <Widget>[
                                                        Expanded(
                                                          child: Text(
                                                            'Comanda ${listedComanda.identifier}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .titleLarge,
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: listedComanda.status ==
                                                                    'closed'
                                                                ? const Color(0xFFF3F4F6)
                                                                : const Color(0xFFFFE7EA),
                                                            borderRadius:
                                                                BorderRadius.circular(999),
                                                          ),
                                                          child: Text(
                                                            statusLabel,
                                                            style: TextStyle(
                                                              color: listedComanda.status ==
                                                                      'closed'
                                                                  ? AppTheme.subtitle
                                                                  : AppTheme.primary,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Cliente: ${listedComanda.customerName?.trim().isNotEmpty == true ? listedComanda.customerName : 'Não informado'}',
                                                      style: const TextStyle(
                                                        color: AppTheme.subtitle,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    if (previewItems.isEmpty)
                                                      const Text(
                                                        'Nenhum item lançado ainda.',
                                                      )
                                                    else
                                                      ...previewItems.map(
                                                        (item) => Padding(
                                                          padding:
                                                              const EdgeInsets.only(bottom: 6),
                                                          child: Row(
                                                            children: <Widget>[
                                                              Expanded(
                                                                child: Text(item.name),
                                                              ),
                                                              Text(
                                                                'R\$ ${item.price.toStringAsFixed(2).replaceAll('.', ',')}',
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    if (listedComanda.items.length > 2)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Text(
                                                          '+${listedComanda.items.length - 2} itens',
                                                          style: const TextStyle(
                                                            color: AppTheme.subtitle,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: <Widget>[
                                                        const Expanded(
                                                          child: Text(
                                                            'Total',
                                                            style: TextStyle(
                                                              color: AppTheme.subtitle,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          'R\$ ${listedComanda.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w700,
                                                            color: AppTheme.title,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: <Widget>[
                                                        OutlinedButton(
                                                          onPressed: () =>
                                                              _showOpenComandaDetails(
                                                            listedComanda,
                                                          ),
                                                          child: const Text(
                                                            'Ver Detalhes',
                                                          ),
                                                        ),
                                                        if (listedComanda.status == 'open')
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                _closeComanda(
                                                              listedComanda,
                                                            ),
                                                            child: const Text(
                                                              'Fechar Comanda',
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  floatingActionButton: selectedHomeSection == 1
                      ? FloatingActionButton(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          onPressed: _openCreateComandaDialog,
                          child: const Icon(Icons.add),
                        )
                      : null,
                  bottomNavigationBar: selectedHomeSection == 0
                      ? SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border:
                                  Border(top: BorderSide(color: Color(0xFFEFEFEF))),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Text(
                                        'Comanda atual',
                                        style: TextStyle(color: AppTheme.subtitle),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comanda.identifier,
                                        style: const TextStyle(
                                          color: AppTheme.subtitle,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 132,
                                  child: ElevatedButton(
                                    onPressed: () => _showSummary(comanda),
                                    child: Text(
                                      comanda.items.isEmpty
                                          ? 'Resumo'
                                          : 'Resumo (${comanda.items.length})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
}
