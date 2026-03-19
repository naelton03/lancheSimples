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
    required this.isDeviceConfigured,
    required this.onEnterHome,
    required this.onOnboardingCompleted,
  });

  final AppDataService dataService;
  final LocalStorageService storageService;
  final FirebaseInitializationState firebaseState;
  final bool isDeviceConfigured;
  final VoidCallback onEnterHome;
  final VoidCallback onOnboardingCompleted;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController tenantIdController = TextEditingController();
  late Future<List<Tenant>> tenantsFuture;
  late Future<_SavedDeviceAccess?> savedDeviceAccessFuture;
  int logoTapCount = 0;

  @override
  void initState() {
    super.initState();
    tenantsFuture = widget.dataService.getTenants();
    savedDeviceAccessFuture = _loadSavedDeviceAccess();
  }

  @override
  void dispose() {
    tenantIdController.dispose();
    super.dispose();
  }

  void _reloadTenants() {
    setState(() {
      tenantsFuture = widget.dataService.getTenants();
      savedDeviceAccessFuture = _loadSavedDeviceAccess();
    });
  }

  Future<_SavedDeviceAccess?> _loadSavedDeviceAccess() async {
    final tenantId = await widget.storageService.getTenantId();
    final employeeName = await widget.storageService.getEmployeeName();
    final normalizedTenantId = tenantId?.trim().toUpperCase() ?? '';
    final normalizedEmployeeName = employeeName?.trim() ?? '';

    if (normalizedTenantId.isEmpty || normalizedEmployeeName.isEmpty) {
      return null;
    }

    return _SavedDeviceAccess(
      tenantId: normalizedTenantId,
      employeeName: normalizedEmployeeName,
    );
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
      if (!mounted) {
        return;
      }
      _reloadTenants();
    });
  }

  void _handleEnterHome() {
    widget.onEnterHome();
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

    if (!mounted) {
      return;
    }

    if (!isAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código inválido.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MasterAdminPanelScreen(dataService: widget.dataService),
      ),
    );

    if (!mounted) {
      return;
    }

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
            if (widget.isDeviceConfigured)
              FutureBuilder<_SavedDeviceAccess?>(
                future: savedDeviceAccessFuture,
                builder: (context, snapshot) {
                  final savedAccess = snapshot.data;

                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Dispositivo pronto para uso',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          savedAccess == null
                              ? 'O onboarding já foi concluído neste dispositivo.'
                              : 'Tenant ${savedAccess.tenantId} • operador ${savedAccess.employeeName}.',
                          style: const TextStyle(color: AppTheme.subtitle),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleEnterHome,
                            child: const Text('Entrar no PDV'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              if (savedAccess != null) {
                                tenantIdController.text = savedAccess.tenantId;
                              }
                              _openOnboarding();
                            },
                            child: const Text('Atualizar onboarding'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else ...<Widget>[
              TextField(
                controller: tenantIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Tenant ID',
                  hintText: 'Ex.: TENANT-1001',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openOnboarding,
                  child: const Text('Continuar'),
                ),
              ),
            ],
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

class _SavedDeviceAccess {
  const _SavedDeviceAccess({
    required this.tenantId,
    required this.employeeName,
  });

  final String tenantId;
  final String employeeName;
}
