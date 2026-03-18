import 'package:flutter/material.dart';

import '../services/local_storage_service.dart';
import '../services/mock_data_service.dart';
import 'master_admin_panel_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.dataService,
    required this.storageService,
    required this.onOnboardingCompleted,
  });

  final MockDataService dataService;
  final LocalStorageService storageService;
  final VoidCallback onOnboardingCompleted;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController tenantIdController = TextEditingController();
  int logoTapCount = 0;

  @override
  void dispose() {
    tenantIdController.dispose();
    super.dispose();
  }

  void _openOnboarding() {
    final tenantId = tenantIdController.text.trim();

    if (tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o Tenant ID para continuar.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingScreen(
          dataService: widget.dataService,
          storageService: widget.storageService,
          initialTenantId: tenantId,
          onCompleted: widget.onOnboardingCompleted,
        ),
      ),
    );
  }

  Future<void> _handleHiddenAccess() async {
    logoTapCount += 1;
    if (logoTapCount < 5) {
      return;
    }
    logoTapCount = 0;

    final TextEditingController codeController = TextEditingController();
    final isAuthorized = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Acesso Master Admin'),
              content: TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Código secreto',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final authorized =
                        codeController.text.trim() == MockDataService.masterCode;
                    Navigator.of(context).pop(authorized);
                  },
                  child: const Text('Entrar'),
                ),
              ],
            );
          },
        ) ??
        false;

    codeController.dispose();

    if (!mounted || !isAuthorized) {
      if (!isAuthorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código inválido.')),
        );
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MasterAdminPanelScreen(dataService: widget.dataService),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(),
              GestureDetector(
                onTap: _handleHiddenAccess,
                onLongPress: _handleHiddenAccess,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LancheSimples',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PDV móvel multi-tenant para operação rápida de lanchonetes.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: tenantIdController,
                decoration: const InputDecoration(
                  labelText: 'Tenant ID',
                  hintText: 'Ex.: TENANT-1001',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openOnboarding,
                child: const Text('Continuar'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Dica: toque repetidamente no logo ou pressione e segure '
                'para acesso administrativo.',
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
