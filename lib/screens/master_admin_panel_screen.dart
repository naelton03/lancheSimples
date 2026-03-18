import 'package:flutter/material.dart';

import '../models/tenant.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';

class MasterAdminPanelScreen extends StatefulWidget {
  const MasterAdminPanelScreen({
    super.key,
    required this.dataService,
  });

  final MockDataService dataService;

  @override
  State<MasterAdminPanelScreen> createState() => _MasterAdminPanelScreenState();
}

class _MasterAdminPanelScreenState extends State<MasterAdminPanelScreen> {
  final TextEditingController nameController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _createTenant() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da lanchonete.')),
      );
      return;
    }

    final tenant = widget.dataService.createTenant(name);
    nameController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tenant criado: ${tenant.tenantId}')),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tenants = widget.dataService.getTenants();

    return Scaffold(
      appBar: AppBar(title: const Text('Master Admin Panel')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Criar nova lanchonete',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Cadastre apenas o nome do estabelecimento para gerar o tenant_id único.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Lanchonete',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _createTenant,
                child: const Text('Criar Lanchonete'),
              ),
              const SizedBox(height: 24),
              Text(
                'Tenants gerados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: tenants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final Tenant tenant = tenants[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF0F0F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tenant.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.title,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tenant.tenantId,
                            style: const TextStyle(color: AppTheme.subtitle),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
