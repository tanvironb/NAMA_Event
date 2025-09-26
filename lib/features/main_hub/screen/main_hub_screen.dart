// lib/features/main_hub/screen/main_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/home/screen/attendee_shell.dart';
import 'package:events_app_trueattempt/features/home/screen/speaker_shell.dart';
import 'package:events_app_trueattempt/features/home/screen/admin_shell.dart';

class MainHubScreen extends ConsumerWidget {
  const MainHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

    return userProfileAsync.when(
      data: (user) {
        if (user == null) {
          // This should ideally not happen if AuthGate is working,
          // but as a fallback, show an error and a way to log out.
          return const Scaffold(body: Center(child: Text('Error: User not found.')));
        }

        // Route to the correct shell based on user role
        switch (user.role) {
          case 'admin':
            return const AdminShell();
          case 'speaker':
            return const SpeakerShell();
          case 'attendee':
          default:
            return const AttendeeShell();
        }
      },
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error loading profile: $err'))),
    );
  }
}