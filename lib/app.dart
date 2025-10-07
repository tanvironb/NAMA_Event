import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/screen/auth_gate.dart';
import 'config/app_themes.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/splash_screen.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A future that represents all necessary initializations
    final appInitialization = ref.watch(appInitializationProvider);

    return MaterialApp(
      navigatorKey: navigatorKey, // Use the global navigatorKey from notification_services.dart
      title: 'NAMA Foundation Event App',
      theme: AppTheme.lightTheme, // Default to light theme reflecting company brand
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Force light theme as default
      debugShowCheckedModeBanner: false,
      home: appInitialization.when(
        data: (_) => const AuthGate(),
        loading: () => const SplashScreen(),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Initialization Error: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Trigger a restart by invalidating the provider
                    ref.invalidate(appInitializationProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      // Add basic named routes for notification deep linking
      routes: {
        '/agenda': (context) => const AuthGate(), // Will navigate to agenda tab
        '/networking': (context) => const AuthGate(), // Will navigate to networking tab
        '/notifications': (context) => const AuthGate(), // Will navigate to notifications
      },
    );
  }
}