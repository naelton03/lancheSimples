import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/firebase_initialization_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_data_service.dart';
import 'services/local_storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseState = await _initializeFirebaseSafely();
  runApp(MyApp(firebaseState: firebaseState));
}

Future<FirebaseInitializationState> _initializeFirebaseSafely() async {
  if (kIsWeb) {
    return const FirebaseInitializationState(
      isReady: false,
      message: 'Firebase desabilitado na build web deste MVP.',
    );
  }

  if (!DefaultFirebaseOptions.hasValidConfiguration) {
    return const FirebaseInitializationState(
      isReady: false,
      message: 'Firebase ainda não configurado nesta branch. App iniciado em modo local.',
    );
  }

  try {
    final options = switch (defaultTargetPlatform) {
      TargetPlatform.android => DefaultFirebaseOptions.android,
      TargetPlatform.iOS => DefaultFirebaseOptions.ios,
      TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.fuchsia => null,
    };

    if (options == null) {
      return const FirebaseInitializationState(
        isReady: false,
        message: 'Firebase não configurado para esta plataforma.',
      );
    }

    await Firebase.initializeApp(options: options);

    return const FirebaseInitializationState(
      isReady: true,
      message: 'Firebase inicializado com sucesso. Banco de dados remoto ativo.',
    );
  } on FirebaseException catch (error) {
    return FirebaseInitializationState(
      isReady: false,
      message: 'Falha ao inicializar o Firebase: ${error.message ?? error.code}. App iniciou em modo local.',
    );
  } catch (error) {
    return FirebaseInitializationState(
      isReady: false,
      message: 'Falha inesperada ao inicializar o Firebase: $error. App iniciou em modo local.',
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.firebaseState,
  });

  final FirebaseInitializationState firebaseState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LancheSimples',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AppBootstrapper(firebaseState: firebaseState),
    );
  }
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({
    super.key,
    required this.firebaseState,
  });

  final FirebaseInitializationState firebaseState;

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  final LocalStorageService storageService = LocalStorageService();
  late final AppDataService dataService;
  late Future<bool> onboardingFuture;
  bool hasActiveSession = false;

  @override
  void initState() {
    super.initState();
    dataService = AppDataService(
      firestore: widget.firebaseState.isReady ? FirebaseFirestore.instance : null,
    );
    onboardingFuture = storageService.isOnboardingComplete();
  }

  @override
  void dispose() {
    dataService.dispose();
    super.dispose();
  }

  void _refreshOnboardingStatus() {
    setState(() {
      hasActiveSession = false;
      onboardingFuture = storageService.isOnboardingComplete();
    });
  }

  void _handleOnboardingCompleted() {
    setState(() {
      hasActiveSession = true;
      onboardingFuture = storageService.isOnboardingComplete();
    });
  }

  void _startSession() {
    setState(() {
      hasActiveSession = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: onboardingFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true && hasActiveSession) {
          return HomeScreen(
            dataService: dataService,
            storageService: storageService,
            onResetDevice: _refreshOnboardingStatus,
          );
        }

        return LoginScreen(
          dataService: dataService,
          storageService: storageService,
          firebaseState: widget.firebaseState,
          isDeviceConfigured: snapshot.data == true,
          onEnterHome: _startSession,
          onOnboardingCompleted: _handleOnboardingCompleted,
        );
      },
    );
  }
}
