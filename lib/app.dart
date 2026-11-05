import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:events_app_trueattempt/common_widgets/splash_screen.dart';
import 'package:events_app_trueattempt/config/app_themes.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/services/notification_handler.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_gate.dart';
import 'package:events_app_trueattempt/features/notifications/services/alert_notification_service.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({
    super.key,
    this.enableAlertNotifications = true,
    this.splashDuration,
    this.homeOverride,
  });

  /// Allows widget tests to skip Firebase-backed alert initialization.
  final bool enableAlertNotifications;

  /// Overrides the normal splash duration when provided.
  final Duration? splashDuration;

  /// Allows widget tests to display a home without initializing Firebase.
  final Widget? homeOverride;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final AlertNotificationService _alertService =
      AlertNotificationService();

  bool _showSplash = true;

  Duration get _effectiveSplashDuration {
    return widget.splashDuration ??
        (kIsWeb
            ? const Duration(milliseconds: 900)
            : const Duration(seconds: 5));
  }

  @override
  void initState() {
    super.initState();

    // Skip splash timers when a test home is being used.
    if (widget.homeOverride == null) {
      Future.delayed(_effectiveSplashDuration, () {
        if (!mounted) return;

        setState(() {
          _showSplash = false;
        });
      });
    }

    // Native notification alerts should only initialize on mobile.
    // Tests can disable them because Firebase is not initialized there.
    if (!kIsWeb &&
        widget.enableAlertNotifications &&
        widget.homeOverride == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final currentContext =
            NotificationHandler.navigatorKey.currentContext;

        if (!mounted || currentContext == null) {
          return;
        }

        await _alertService.initialize(currentContext);

        final updatedContext =
            NotificationHandler.navigatorKey.currentContext;

        if (!mounted || updatedContext == null) {
          return;
        }

        await _alertService.checkForUnshownAlerts(
          updatedContext,
        );
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && widget.enableAlertNotifications) {
      _alertService.dispose();
    }

    super.dispose();
  }

  void _restartSplash() {
    setState(() {
      _showSplash = true;
    });

    final retryDuration = widget.splashDuration ??
        (kIsWeb
            ? const Duration(milliseconds: 700)
            : const Duration(seconds: 5));

    Future.delayed(retryDuration, () {
      if (!mounted) return;

      setState(() {
        _showSplash = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appInitialization = widget.homeOverride == null
        ? ref.watch(appInitializationProvider)
        : null;

    return MaterialApp(
      navigatorKey: NotificationHandler.navigatorKey,
      title: 'NAMA Foundation Event App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,

      home: widget.homeOverride ??
          (_showSplash
              ? const SplashScreen()
              : appInitialization!.when(
                  data: (_) => const AuthGate(),
                  loading: () => const SplashScreen(),
                  error: (error, stackTrace) {
                    return _InitializationErrorScreen(
                      error: error,
                      onRetry: () {
                        ref.invalidate(appInitializationProvider);
                        _restartSplash();
                      },
                    );
                  },
                )),

      routes: {
        '/agenda': (_) => const AuthGate(),
        '/networking': (_) => const AuthGate(),
        '/notifications': (_) => const AuthGate(),
      },
    );
  }
}

class _InitializationErrorScreen extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _InitializationErrorScreen({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}