// lib/features/main_hub/screen/main_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/home/screen/attendee_shell.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_shell.dart';
import 'package:events_app_trueattempt/features/home/screen/admin_shell.dart';
import 'package:events_app_trueattempt/common_widgets/in_app_notification_handler.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/privacy/widgets/privacy_selection_dialog.dart';
import 'package:events_app_trueattempt/core/enums/profile_visibility.dart';

class MainHubScreen extends ConsumerStatefulWidget {
  const MainHubScreen({super.key});

  @override
  ConsumerState<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends ConsumerState<MainHubScreen> {
  @override
  void initState() {
    super.initState();
    // Show privacy selection dialog after first frame if user hasn't selected privacy level yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPrivacySelectionDialog();
    });
  }

  Future<void> _checkAndShowPrivacySelectionDialog() async {
    final userProfileAsync = ref.read(userAppProfileStreamProvider);
    final user = userProfileAsync.value;
    
    // Show privacy selection dialog if user hasn't selected privacy level yet
    if (user != null && user.needsPrivacySelection && mounted) {
      _showPrivacySelectionDialog(user.profileVisibility);
    }
  }

  void _showPrivacySelectionDialog(String currentVisibility) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PrivacySelectionDialog(
        initialSelection: ProfileVisibility.fromString(currentVisibility),
        canDismiss: false, // Cannot skip first-time selection
        onConfirm: (selectedLevel) async {
          // Update user's privacy level in Firestore
          final currentUser = ref.read(currentUserProvider);
          if (currentUser != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'profileVisibility': selectedLevel.value,
              'privacySelectedAt': FieldValue.serverTimestamp(),
            });
            
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

    return userProfileAsync.when(
      data: (user) {
        if (user == null) {
          // This should never happen due to AuthGate-level security, but as fallback
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

        // Status checking is now handled by AuthGate, so we only route by role here
        // Route to the correct shell based on user role
        Widget shell;
        switch (user.role) {
          case 'admin':
            shell = const AdminShell();
            break;
          case 'speaker':
            shell = const SpeakerShell();
            break;
          case 'staff':
            // Staff users get the same interface as users but with QR scanning privileges
            shell = const AttendeeShell();
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