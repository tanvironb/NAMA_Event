// lib/features/main_hub/screen/main_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/home/screen/attendee_shell.dart';
import 'package:events_app_trueattempt/features/home/screen/staff_shell.dart';
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
  bool _privacyDialogShown = false;
  String? _lastDialogCheckedUid;

  Future<void> _checkAndShowPrivacySelectionDialog({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    if (_privacyDialogShown || !mounted) return;

    if (_lastDialogCheckedUid == uid) return;
    _lastDialogCheckedUid = uid;

    final privacySelectedAt = userData['privacySelectedAt'];
    final needsPrivacySelection = privacySelectedAt == null;

    final currentVisibility =
        (userData['profileVisibility'] ?? 'minimal').toString();

    if (needsPrivacySelection && mounted) {
      _privacyDialogShown = true;
      _showPrivacySelectionDialog(currentVisibility);
    }
  }

  void _showPrivacySelectionDialog(String currentVisibility) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PrivacySelectionDialog(
        initialSelection: ProfileVisibility.fromString(currentVisibility),
        canDismiss: false,
        onConfirm: (selectedLevel) async {
          final currentUser = ref.read(firebaseAuthProvider).currentUser;

          if (currentUser != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'profileVisibility': selectedLevel.value,
              'privacySelectedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        },
      ),
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Your account is not authorized for this application.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(authViewModelProvider.notifier).signOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeRole(Map<String, dynamic> userData) {
    final rawRole = (userData['role'] ??
            userData['userRole'] ??
            userData['userType'] ??
            userData['type'] ??
            'attendee')
        .toString()
        .trim()
        .toLowerCase();

    if (rawRole == 'administrator') return 'admin';
    if (rawRole == 'admins') return 'admin';
    if (rawRole == 'speaker_user') return 'speaker';
    if (rawRole == 'staff_user') return 'staff';
    if (rawRole == 'user') return 'attendee';

    return rawRole;
  }

  Widget _getShellByRole(String role) {
    switch (role) {
      case 'admin':
        return AdminShell(
          key: ValueKey('admin_shell_$role'),
        );

      case 'speaker':
        return SpeakerShell(
          key: ValueKey('speaker_shell_$role'),
        );

      case 'staff':
        return StaffShell(
          key: ValueKey('staff_shell_$role'),
        );

      case 'attendee':
      default:
        return AttendeeShell(
          key: ValueKey('attendee_shell_$role'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = ref.watch(firebaseAuthProvider).currentUser;

    if (firebaseUser == null) {
      return _buildAccessDenied(context);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: LoadingIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error loading profile: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildAccessDenied(context);
        }

        final userData = snapshot.data!.data();

        if (userData == null) {
          return _buildAccessDenied(context);
        }

        final role = _normalizeRole(userData);

        debugPrint('MainHubScreen current user uid: ${firebaseUser.uid}');
        debugPrint('MainHubScreen current role: $role');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowPrivacySelectionDialog(
            uid: firebaseUser.uid,
            userData: userData,
          );
        });

        final shell = _getShellByRole(role);

        return KeyedSubtree(
          key: ValueKey('main_hub_shell_${firebaseUser.uid}_$role'),
          child: InAppNotificationHandler(
            key: ValueKey('main_hub_notification_${firebaseUser.uid}_$role'),
            child: shell,
          ),
        );
      },
    );
  }
}