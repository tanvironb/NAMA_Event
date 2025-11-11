// lib/features/main_hub/screen/main_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/home/screen/attendee_shell.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_shell.dart';
import 'package:events_app_trueattempt/features/home/screen/admin_shell.dart';
import 'package:events_app_trueattempt/common_widgets/in_app_notification_handler.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class MainHubScreen extends ConsumerStatefulWidget {
  const MainHubScreen({super.key});

  @override
  ConsumerState<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends ConsumerState<MainHubScreen> {
  @override
  void initState() {
    super.initState();
    // Show privacy dialog after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPrivacyDialog();
    });
  }

  Future<void> _checkAndShowPrivacyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenPrivacy = prefs.getBool('has_seen_privacy_dialog') ?? false;
    
    if (!hasSeenPrivacy && mounted) {
      _showPrivacyDialog();
    }
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: AppColors.namaNavyBlue),
            const SizedBox(width: 12),
            const Text(
              'Privacy Notice',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We value your privacy and want you to feel secure while using our app.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your Information:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Your profile data is stored securely\n'
                '• We only collect information necessary for event participation\n'
                '• Your data will not be shared with third parties without consent\n'
                '• You can update or delete your account at any time',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'By continuing, you acknowledge that you have read and understood our privacy practices.',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_seen_privacy_dialog', true);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.namaNavyBlue,
              foregroundColor: AppColors.namaWhite,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('I Understand'),
          ),
        ],
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