import 'package:flutter/material.dart';

import '../services/local_storage_service.dart';
import '../services/mock_data_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.dataService,
    required this.storageService,
    required this.initialTenantId,
    required this.onCompleted,
  });

  final MockDataService dataService;
  final LocalStorageService storageService;
  final String initialTenantId;
  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController tenantIdController;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController cpfController = TextEditingController();

  @override
  void initState() {
    super.initState();
    tenantIdController = TextEditingController(text: widget.initialTenantId);
  }

  @override
  void dispose() {
    tenantIdController.dispose();
    nameController.dispose();
    cpfController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final tenantId = tenantIdController.text.trim();
    final name = nameController.text.trim();
    final cpf = cpfController.text.trim();

    if (!widget.dataService.isValidTenant(tenantId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant ID inválido.')),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do funcionário.')),
      );
      return;
    }

    await widget.storageService.saveOnboarding(
      tenantId: tenantId,
      employeeName: name,
      employeeCpf: cpf,
    );

    if (!mounted) {
      return;
    }

    widget.onCompleted();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Configurar dispositivo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Informe o tenant_id e os dados do operador para rastreabilidade dos pedidos.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: tenantIdController,
              decoration: const InputDecoration(labelText: 'Tenant ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Funcionário',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cpfController,
              decoration: const InputDecoration(
                labelText: 'CPF (Opcional)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _finishOnboarding,
              child: const Text('Finalizar'),
            ),
          ],
        ),
      ),
    );
  }
}
