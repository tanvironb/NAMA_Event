// lib/features/auth/screen/auth_gate.dart

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:events_app_trueattempt/features/main_hub/screen/main_hub_screen.dart';

const Duration _sessionTimeout = Duration(days: 10);

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _sessionTimeoutTriggered = false;

  Future<User?> _reloadAndGetUser(User user) async {
    try {
      await user.reload();
      return FirebaseAuth.instance.currentUser;
    } catch (e) {
      debugPrint('AuthGate reload user error: $e');
      return FirebaseAuth.instance.currentUser;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUserProfile(
    String uid,
  ) async {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            throw Exception(
              'Profile loading timed out. Please check Firestore connection or users/$uid document.',
            );
          },
        );
  }

  DateTime? _parseLastSeen(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  void _triggerSessionTimeout() {
    if (_sessionTimeoutTriggered) return;

    _sessionTimeoutTriggered = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authViewModelProvider.notifier).signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user == null || user.email == null) {
          return const LoginScreen();
        }

        return FutureBuilder<User?>(
          future: _reloadAndGetUser(user),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: LoadingIndicator(),
              );
            }

            final refreshedUser =
                userSnapshot.data ?? FirebaseAuth.instance.currentUser;

            if (refreshedUser == null || refreshedUser.email == null) {
              return const LoginScreen();
            }

            if (!refreshedUser.emailVerified) {
              return const EmailVerificationScreen();
            }

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _loadUserProfile(refreshedUser.uid),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: LoadingIndicator(),
                  );
                }

                if (profileSnapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Profile Loading Failed',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${profileSnapshot.error}',
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
                                ref
                                    .read(authViewModelProvider.notifier)
                                    .signOut();
                              },
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final profileDoc = profileSnapshot.data;

                if (profileDoc == null || !profileDoc.exists) {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 60,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Profile Not Found',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No user profile found for:\n${refreshedUser.email}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                ref
                                    .read(authViewModelProvider.notifier)
                                    .signOut();
                              },
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final data = profileDoc.data() ?? {};

                final status = (data['status'] ?? 'pending').toString();
                final lastSeen = _parseLastSeen(data['lastSeen']);

                if (lastSeen != null) {
                  final inactiveDuration = DateTime.now().difference(lastSeen);

                  if (inactiveDuration >= _sessionTimeout) {
                    _triggerSessionTimeout();

                    return Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_off,
                              size: 60,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Session Expired',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your session has expired due to inactivity.\nPlease sign in again.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const CircularProgressIndicator(),
                          ],
                        ),
                      ),
                    );
                  }
                }

                switch (status) {
                  case 'approved':
                    _sessionTimeoutTriggered = false;
                    return const MainHubScreen();

                  case 'blocked':
                    return const BlockedScreen();

                  case 'rejected':
                    return Scaffold(
                      body: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.block,
                                size: 60,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Access Denied',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Your account has been rejected.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  ref
                                      .read(authViewModelProvider.notifier)
                                      .signOut();
                                },
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        ),
                      ),
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
      loading: () => const Scaffold(
        body: LoadingIndicator(),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Authentication Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.refresh(authStateChangesProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}