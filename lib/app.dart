import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/screen/auth_gate.dart';
import 'config/app_themes.dart';
import 'package:events_app_trueattempt/core/services/notification_handler.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/splash_screen.dart';
import 'package:events_app_trueattempt/features/notifications/services/alert_notification_service.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _alertService = AlertNotificationService();

  @override
  void initState() {
    super.initState();
    // Initialize alert service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && NotificationHandler.navigatorKey.currentContext != null) {
        await _alertService.initialize(NotificationHandler.navigatorKey.currentContext!);
        // Check for unshown alerts after initialization completes
        if (mounted && NotificationHandler.navigatorKey.currentContext != null) {
          await _alertService.checkForUnshownAlerts(NotificationHandler.navigatorKey.currentContext!);
        }
      }
    });
  }

  @override
  void dispose() {
    _alertService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A future that represents all necessary initializations
    final appInitialization = ref.watch(appInitializationProvider);

    return MaterialApp(
      navigatorKey: NotificationHandler.navigatorKey, // Use the global navigatorKey from notification_handler.dart
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