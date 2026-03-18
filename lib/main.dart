import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/local_storage_service.dart';
import 'services/mock_data_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LancheSimples',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppBootstrapper(),
    );
  }
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  final LocalStorageService storageService = LocalStorageService();
  final MockDataService dataService = MockDataService();

  late Future<bool> onboardingFuture;

  @override
  void initState() {
    super.initState();
    onboardingFuture = storageService.isOnboardingComplete();
  }

  void _refreshOnboardingStatus() {
    setState(() {
      onboardingFuture = storageService.isOnboardingComplete();
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

        if (snapshot.data == true) {
          return HomeScreen(
            dataService: dataService,
            storageService: storageService,
          );
        }

        return LoginScreen(
          dataService: dataService,
          storageService: storageService,
          onOnboardingCompleted: _refreshOnboardingStatus,
        );
      },
    );
  }
}
