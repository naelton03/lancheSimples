import 'package:flutter/material.dart';

import '../models/firebase_initialization_state.dart';
import '../models/tenant.dart';
import '../services/app_data_service.dart';
import '../services/local_storage_service.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import 'master_admin_panel_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.dataService,
    required this.storageService,
    required this.firebaseState,
    required this.onOnboardingCompleted,
  });

  final AppDataService dataService;
  final LocalStorageService storageService;
  final FirebaseInitializationState firebaseState;
  final VoidCallback onOnboardingCompleted;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController tenantIdController = TextEditingController();
  late Future<List<Tenant>> tenantsFuture;
  int logoTapCount = 0;

  @override
  void initState() {
    super.initState();
    tenantsFuture = widget.dataService.getTenants();
  }

  @override
  void dispose() {
    tenantIdController.dispose();
    super.dispose();
  }

  void _reloadTenants() {
    setState(() {
      tenantsFuture = widget.dataService.getTenants();
    });
  }

  void _openOnboarding() {
    final tenantId = tenantIdController.text.trim().toUpperCase();

    if (tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o Tenant ID para continuar.')),
      );
      return;
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingScreen(
          dataService: widget.dataService,
          storageService: widget.storageService,
          initialTenantId: tenantId,
          onCompleted: widget.onOnboardingCompleted,
        ),
      ),
    )
        .then((_) {
      _reloadTenants();
    });
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

    _reloadTenants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const SizedBox(height: 32),
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.firebaseState.isReady
                    ? const Color(0xFFF0FFF4)
                    : const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.firebaseState.isReady
                      ? const Color(0xFFC6F6D5)
                      : const Color(0xFFFFD7D9),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.dataService.isRemoteEnabled
                        ? 'Banco de dados remoto ativo'
                        : 'Modo local ativo',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.title,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.firebaseState.message,
                    style: const TextStyle(color: AppTheme.subtitle),
                  ),
                ],
              ),
            ),
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
              textCapitalization: TextCapitalization.characters,
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
            const SizedBox(height: 24),
            Text(
              'Tenants disponíveis para teste',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Tenant>>(
              future: tenantsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final tenants = snapshot.data!;
                if (tenants.isEmpty) {
                  return const Text('Nenhum tenant disponível no momento.');
                }

                return Column(
                  children: tenants
                      .map(
                        (tenant) => Card(
                          child: ListTile(
                            title: Text(tenant.name),
                            subtitle: Text(tenant.tenantId),
                            trailing: TextButton(
                              onPressed: () {
                                tenantIdController.text = tenant.tenantId;
                              },
                              child: const Text('Usar'),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
