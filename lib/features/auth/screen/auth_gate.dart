import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/auth/screen/blocked_screen.dart';
import 'package:events_app_trueattempt/features/auth/screen/email_verification_screen.dart';
import 'package:events_app_trueattempt/features/auth/screen/login_screen.dart';
import 'package:events_app_trueattempt/features/auth/screen/pending_approval_screen.dart';
import 'package:events_app_trueattempt/features/event_join/screen/event_join_welcome_screen.dart';
import 'package:events_app_trueattempt/features/main_hub/screen/main_hub_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _userId;
  Future<User?>? _userFuture;
  Future<DocumentSnapshot<Map<String, dynamic>>>? _profileFuture;
  Future<bool>? _admissionFuture;

  void _clearCachedState() {
    _userId = null;
    _userFuture = null;
    _profileFuture = null;
    _admissionFuture = null;
  }

  void _prepareUser(User user) {
    if (_userId == user.uid && _userFuture != null) return;

    _clearCachedState();
    _userId = user.uid;
    _userFuture = _reloadAndGetUser(user);
  }

  void _retry() {
    if (!mounted) return;
    setState(_clearCachedState);
  }

  Future<void> _signOut() async {
    await ref.read(authViewModelProvider.notifier).signOut();
    if (mounted) {
      setState(_clearCachedState);
    }
  }

  Future<User?> _reloadAndGetUser(User user) async {
    try {
      await user.reload();
    } catch (error) {
      debugPrint('AuthGate reload user error: $error');
    }
    return FirebaseAuth.instance.currentUser;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUserProfile(
    String uid,
  ) {
    return _db.collection('users').doc(uid).get().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        throw Exception(
          'Profile loading timed out. Please check your connection.',
        );
      },
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>>
      _loadUserProfileAndSyncVerification(User user) async {
    final profile = await _loadUserProfile(user.uid);

    // Do not create a missing profile during verification syncing.
    if (!profile.exists) return profile;

    if (user.emailVerified &&
        profile.data()?['emailVerified'] != true) {
      await profile.reference.set(
        {
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return _loadUserProfile(user.uid);
    }

    return profile;
  }

  Future<bool> _hasVerifiedAdmission(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    final candidateIds = <String>{};

    void addEventId(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        candidateIds.add(value.trim());
      }
    }

    addEventId(userData['currentEventId']);
    addEventId(userData['activeEventId']);

    final eventIds = userData['eventIds'];
    if (eventIds is List) {
      for (final eventId in eventIds) {
        addEventId(eventId);
      }
    }

    for (final eventId in candidateIds) {
      final eventRef = _db.collection('events').doc(eventId);
      final event = await eventRef.get();

      if (!event.exists) continue;

      final eventData = event.data() ?? {};
      final status = (eventData['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (eventData['isActive'] != true || status == 'archived') {
        continue;
      }

      final registration = await eventRef
          .collection('registrations')
          .doc(uid)
          .get();

      if (registration.data()?['admissionVerified'] == true) {
        return true;
      }
    }

    return false;
  }

  Future<String> _joinEvent(
    String credential, {
    required bool fromQr,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please sign in again.');
    }

    try {
      // Refresh the token so the callable sees email verification.
      await user.getIdToken(true);

      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('joinActiveEvent').call({
        'credential': credential.trim(),
        'fromQr': fromQr,
      });

      final response = result.data;
      if (response is! Map) {
        throw Exception('Unable to confirm event admission. Please retry.');
      }

      final eventId = (response['eventId'] ?? '').toString().trim();

      if (response['success'] != true || eventId.isEmpty) {
        throw Exception('Unable to confirm event admission. Please retry.');
      }

      // The welcome screen first closes its scanner route, then invokes
      // onEventJoined. Keep this gate unchanged until that callback.
      return eventId;
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Unable to join the event. Please try again.',
      );
    }
  }

  Future<void> _onEventJoined(
    BuildContext context,
    String eventId,
  ) async {
    if (!mounted) return;

    // Re-read the profile and server-written registration before routing.
    setState(_clearCachedState);
  }

  Widget _loading() {
    return const Scaffold(body: LoadingIndicator());
  }

  Widget _messageScreen({
    required String title,
    required String message,
    required IconData icon,
    bool allowRetry = false,
  }) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 60,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (allowRetry) ...[
                ElevatedButton(
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 10),
              ],
              TextButton(
                onPressed: _signOut,
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _approvedScreen(
    User user,
    Map<String, dynamic> userData,
  ) {
    final role = (userData['role'] ?? 'attendee')
        .toString()
        .trim()
        .toLowerCase();

    if (role == 'admin' || role == 'superadmin') {
      return const MainHubScreen();
    }

    _admissionFuture ??= _hasVerifiedAdmission(
      user.uid,
      userData,
    ).timeout(const Duration(seconds: 20));

    return FutureBuilder<bool>(
      future: _admissionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loading();
        }

        if (snapshot.hasError) {
          return _messageScreen(
            title: 'Unable to Check Event Access',
            message: '${snapshot.error}',
            icon: Icons.error_outline,
            allowRetry: true,
          );
        }

        if (snapshot.data == true) {
          return const MainHubScreen();
        }

        return EventJoinWelcomeScreen(
          onJoinEvent: _joinEvent,
          onEventJoined: _onEventJoined,
          onSignOut: _signOut,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user == null || user.email == null) {
          _clearCachedState();
          return const LoginScreen();
        }

        _prepareUser(user);

        return FutureBuilder<User?>(
          future: _userFuture,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState != ConnectionState.done) {
              return _loading();
            }

            final refreshedUser =
                userSnapshot.data ?? FirebaseAuth.instance.currentUser;

            if (refreshedUser == null || refreshedUser.email == null) {
              return const LoginScreen();
            }

            if (!refreshedUser.emailVerified) {
              // Allow a later rebuild after verification to reload the user.
              _userFuture = null;
              _profileFuture = null;
              _admissionFuture = null;
              return const EmailVerificationScreen();
            }

            _profileFuture ??=
                _loadUserProfileAndSyncVerification(refreshedUser);

            return FutureBuilder<
                DocumentSnapshot<Map<String, dynamic>>>(
              future: _profileFuture,
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState !=
                    ConnectionState.done) {
                  return _loading();
                }

                if (profileSnapshot.hasError) {
                  return _messageScreen(
                    title: 'Profile Loading Failed',
                    message: '${profileSnapshot.error}',
                    icon: Icons.error_outline,
                    allowRetry: true,
                  );
                }

                final profile = profileSnapshot.data;
                if (profile == null || !profile.exists) {
                  return _messageScreen(
                    title: 'Profile Not Found',
                    message:
                        'No user profile found for:\n${refreshedUser.email}',
                    icon: Icons.person_off_outlined,
                  );
                }

                final data = profile.data() ?? {};
                final status = (data['status'] ?? 'pending')
                    .toString()
                    .trim()
                    .toLowerCase();

                switch (status) {
                  case 'approved':
                    return _approvedScreen(refreshedUser, data);
                  case 'blocked':
                    return const BlockedScreen();
                  case 'rejected':
                    return _messageScreen(
                      title: 'Access Denied',
                      message: 'Your account has been rejected.',
                      icon: Icons.block,
                    );
                  case 'pending':
                  default:
                    return const PendingApprovalScreen();
                }
              },
            );
          },
        );
      },
      loading: _loading,
      error: (error, stack) => _messageScreen(
        title: 'Authentication Error',
        message: '$error',
        icon: Icons.error_outline,
        allowRetry: true,
      ),
    );
  }
}