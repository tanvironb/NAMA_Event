// lib/features/main_hub/screen/main_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/services/app_usage_tracking_service.dart';
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

class _MainHubScreenState extends ConsumerState<MainHubScreen>
    with WidgetsBindingObserver {
  final AppUsageTrackingService _usageTrackingService =
      AppUsageTrackingService();

  bool _privacyDialogShown = false;
  bool _usageTrackingStarted = false;
  bool _welcomeNotificationChecked = false;

  String? _lastDialogCheckedUid;
  String? _trackedEventId;
  String? _lastWelcomeCheckedUid;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startUsageTrackingForActiveEvent();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    if (_trackedEventId != null && _trackedEventId!.isNotEmpty) {
      _usageTrackingService.stopScreenTimerAndSave(
        eventId: _trackedEventId!,
      );
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_trackedEventId != null && _trackedEventId!.isNotEmpty) {
        _usageTrackingService.stopScreenTimerAndSave(
          eventId: _trackedEventId!,
        );
      }

      _usageTrackingStarted = false;
    }

    if (state == AppLifecycleState.resumed) {
      _startUsageTrackingForActiveEvent();
    }
  }

  Future<void> _startUsageTrackingForActiveEvent() async {
    if (!mounted) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    try {
      final activeEventSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeEventSnapshot.docs.isEmpty) {
        debugPrint('MainHubScreen: No active event found for usage tracking.');
        return;
      }

      final eventId = activeEventSnapshot.docs.first.id;

      if (_usageTrackingStarted && _trackedEventId == eventId) {
        return;
      }

      if (_trackedEventId != null &&
          _trackedEventId!.isNotEmpty &&
          _trackedEventId != eventId) {
        await _usageTrackingService.stopScreenTimerAndSave(
          eventId: _trackedEventId!,
        );
      }

      _trackedEventId = eventId;
      _usageTrackingStarted = true;

      await _usageTrackingService.trackAppDownloadOrOpen(
        eventId: eventId,
      );

      _usageTrackingService.startScreenTimer();

      debugPrint('MainHubScreen: Usage tracking started for event $eventId');
    } catch (e) {
      debugPrint('MainHubScreen: Failed to start usage tracking: $e');
    }
  }

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

  Future<void> _createWelcomeNotificationIfNeeded({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    if (_lastWelcomeCheckedUid == uid && _welcomeNotificationChecked) return;

    _lastWelcomeCheckedUid = uid;
    _welcomeNotificationChecked = true;

    if (userData['welcomeNotificationSent'] == true) return;

    final role = _normalizeRole(userData);

    if (role != 'attendee' &&
        role != 'speaker' &&
        role != 'moderator' &&
        role != 'staff') {
      return;
    }

    try {
      final activeEventSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeEventSnapshot.docs.isEmpty) {
        debugPrint('MainHubScreen: No active event found for welcome message.');
        return;
      }

      final eventDoc = activeEventSnapshot.docs.first;
      final eventData = eventDoc.data();

      final eventName = (eventData['name'] ??
              eventData['title'] ??
              eventData['eventName'] ??
              'NAMA Event')
          .toString();

      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc('welcome_onboard_${eventDoc.id}');

      final existingNotification = await notificationRef.get();

      if (!existingNotification.exists) {
        await notificationRef.set({
          'eventId': eventDoc.id,
          'eventName': eventName,
          'title': 'Welcome Onboard',
          'subtitle': 'We are glad to have you here',
          'body':
              'Welcome onboard! We are excited to have you as part of $eventName. Explore the app, connect with others, and enjoy a smooth event experience.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'information',
          'targetRole': role,
          'includeDate': true,
          'data': {
            'notificationCategory': 'welcomeOnboard',
            'eventId': eventDoc.id,
            'role': role,
          },
        });
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'welcomeNotificationSent': true,
        'welcomeNotificationSentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('MainHubScreen: Welcome notification created for $uid');
    } catch (e) {
      debugPrint('MainHubScreen: Failed to create welcome notification: $e');
      _welcomeNotificationChecked = false;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account is not authorized for this application.',
                textAlign: TextAlign.center,
              ),
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
      ),
    );
  }

  Widget _buildProfileError(BuildContext context, Object? error) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                'Error Loading Profile',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  ref.read(authViewModelProvider.notifier).signOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
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
    if (rawRole == 'speaker user') return 'speaker';
    if (rawRole == 'speaker-user') return 'speaker';

    if (rawRole == 'moderator_user') return 'moderator';
    if (rawRole == 'moderator user') return 'moderator';
    if (rawRole == 'moderator-user') return 'moderator';
    if (rawRole == 'mod') return 'moderator';

    if (rawRole == 'staff_user') return 'staff';
    if (rawRole == 'staff user') return 'staff';
    if (rawRole == 'staff-user') return 'staff';

    if (rawRole == 'delegate') return 'attendee';
    if (rawRole == 'delegates') return 'attendee';
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
      case 'moderator':
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
          return _buildProfileError(context, snapshot.error);
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

          _createWelcomeNotificationIfNeeded(
            uid: firebaseUser.uid,
            userData: userData,
          );

          _startUsageTrackingForActiveEvent();
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