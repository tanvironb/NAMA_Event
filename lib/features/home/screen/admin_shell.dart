// lib/features/home/screen/admin_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_dashboard_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  NotificationService? _notificationService;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    if (!mounted) return;

    final user = ref.read(firebaseAuthProvider).currentUser;

    if (user != null) {
      debugPrint('AdminShell: Initializing notifications for user ${user.uid}');

      final notificationService = ref.read(
        notificationServiceProvider(user.uid),
      );

      if (notificationService != null) {
        _notificationService = notificationService;
        await notificationService.initialize();

        debugPrint('AdminShell: Notification service initialized successfully');
      } else {
        debugPrint('AdminShell: Notification service is null');
      }
    } else {
      debugPrint('AdminShell: No authenticated user found');
    }
  }

  @override
  void dispose() {
    _notificationService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardScreen();
  }
}