import 'package:flutter/material.dart';

import '../models/item.dart';
import '../services/local_storage_service.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dataService,
    required this.storageService,
  });

  final MockDataService dataService;
  final LocalStorageService storageService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'Todos';
  String employeeName = 'Operador';

  @override
  void initState() {
    super.initState();
    _loadOperator();
  }

  Future<void> _loadOperator() async {
    final storedName = await widget.storageService.getEmployeeName();
    if (!mounted) {
      return;
    }

    setState(() {
      employeeName = storedName?.trim().isNotEmpty == true ? storedName!.trim() : 'Operador';
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.dataService.getCategories();
    final List<Item> items = widget.dataService.getItemsByCategory(selectedCategory);
    final total = items.fold<double>(0, (sum, item) => sum + item.price);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LancheSimples'),
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
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                final selected = category == selectedCategory;
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
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ItemCard(
                  item: item,
                  onAdd: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.name} adicionado à comanda.')),
                    );
                  },
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
                    const Text(
                      'Total do catálogo visível',
                      style: TextStyle(color: AppTheme.subtitle),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
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
                onPressed: () {},
                child: const Text('Resumo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
