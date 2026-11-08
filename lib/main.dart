import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/app_shell.dart';
import 'screens/splash/splash_screen.dart';
import 'services/auth_service.dart';
import 'widgets/common/app_progress_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Task 6: Ensure owner account is pre-seeded in Firebase in the background
  // without blocking the main thread so the app opens instantly.
  AuthService().seedOwnerAccount().timeout(
    const Duration(seconds: 4),
    onTimeout: () => debugPrint('Owner account seeding timed out'),
  ).catchError((e) {
    debugPrint('Owner account seeding error: $e');
  });

  runApp(
    const ProviderScope(
      child: RepairShopApp(),
    ),
  );
}

class RepairShopApp extends ConsumerWidget {
  const RepairShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'SP Mobile Repair',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}

/// Listens to Firebase auth state and routes accordingly.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const AppShell();
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 50),
            child: AppProgressBar(),
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }
}
