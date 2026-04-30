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

  bool _showSplash = true;

  @override
  void initState() {
    super.initState();

    // Always show splash first for 5 seconds.
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _showSplash = false);
    });

    // Initialize alert service after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && NotificationHandler.navigatorKey.currentContext != null) {
        await _alertService.initialize(
          NotificationHandler.navigatorKey.currentContext!,
        );

        if (mounted && NotificationHandler.navigatorKey.currentContext != null) {
          await _alertService.checkForUnshownAlerts(
            NotificationHandler.navigatorKey.currentContext!,
          );
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
    final appInitialization = ref.watch(appInitializationProvider);

    return MaterialApp(
      navigatorKey: NotificationHandler.navigatorKey,
      title: 'NAMA Foundation Event App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,

      home: _showSplash
          ? const SplashScreen()
          : appInitialization.when(
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
                          ref.invalidate(appInitializationProvider);
                          setState(() => _showSplash = true);

                          Future.delayed(const Duration(seconds: 5), () {
                            if (!mounted) return;
                            setState(() => _showSplash = false);
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

      routes: {
        '/agenda': (context) => const AuthGate(),
        '/networking': (context) => const AuthGate(),
        '/notifications': (context) => const AuthGate(),
      },
    );
  }
}