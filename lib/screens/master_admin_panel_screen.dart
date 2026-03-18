import 'package:flutter/material.dart';

import '../models/tenant.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';

class MasterAdminPanelScreen extends StatefulWidget {
  const MasterAdminPanelScreen({
    super.key,
    required this.dataService,
  });

  final AppDataService dataService;

  @override
  State<MasterAdminPanelScreen> createState() => _MasterAdminPanelScreenState();
}

class _MasterAdminPanelScreenState extends State<MasterAdminPanelScreen> {
  final TextEditingController nameController = TextEditingController();
  late Future<List<Tenant>> tenantsFuture;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    tenantsFuture = widget.dataService.getTenants();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _reloadTenants() {
    setState(() {
      tenantsFuture = widget.dataService.getTenants();
    });
  }

  Future<void> _createTenant() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da lanchonete.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final tenant = await widget.dataService.createTenant(name);
      nameController.clear();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tenant pronto para uso: ${tenant.tenantId}')),
      );

      setState(() {
        tenantsFuture = widget.dataService.getTenants();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao criar tenant: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'O cadastro cria o tenant e faz o primeiro seed do catálogo no banco de dados quando o Firebase estiver ativo.',
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
                onPressed: isSaving ? null : _createTenant,
                child: Text(isSaving ? 'Criando...' : 'Criar Lanchonete'),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Tenants gerados',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: _reloadTenants,
                    child: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Tenant>>(
                  future: tenantsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tenants = snapshot.data!;
                    return ListView.separated(
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
