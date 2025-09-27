// lib/features/main_hub/screen/main_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/home/screen/attendee_shell.dart';
import 'package:events_app_trueattempt/features/home/screen/speaker_shell.dart';
import 'package:events_app_trueattempt/features/home/screen/admin_shell.dart';
import 'package:events_app_trueattempt/common_widgets/in_app_notification_handler.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';

class MainHubScreen extends ConsumerWidget {
  const MainHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

    return userProfileAsync.when(
      data: (user) {
        if (user == null) {
          // This should never happen due to auth-level security, but as fallback
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Access Denied', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Your account is not authorized for this application.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }

        // Route to the correct shell based on user role
        Widget shell;
        switch (user.role) {
          case 'admin':
            shell = const AdminShell();
            break;
          case 'speaker':
            shell = const SpeakerShell();
            break;
          case 'attendee':
          default:
            shell = const AttendeeShell();
        }
        return InAppNotificationHandler(child: shell);
      },
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error loading profile: $err'))),
    );
  }
}