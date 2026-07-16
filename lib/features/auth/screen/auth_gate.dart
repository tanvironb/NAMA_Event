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

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
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

  Future<DocumentSnapshot<Map<String, dynamic>>>
      _loadUserProfileAndSyncVerification(User user) async {
    final profileDoc = await _loadUserProfile(user.uid);

    if (user.emailVerified) {
      final data = profileDoc.data();
      final alreadySynced = data != null && data['emailVerified'] == true;

      if (!alreadySynced) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return _loadUserProfile(user.uid);
      }
    }

    return profileDoc;
  }

  Widget _buildProfileLoadingFailed(
    BuildContext context,
    Object? error,
  ) {
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

  Widget _buildProfileNotFound(
    BuildContext context,
    User refreshedUser,
  ) {
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

  Widget _buildRejectedScreen(BuildContext context) {
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
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account has been rejected.',
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

  Widget _buildAuthError(
    BuildContext context,
    Object err,
  ) {
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
    );
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
              future: _loadUserProfileAndSyncVerification(refreshedUser),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: LoadingIndicator(),
                  );
                }

                if (profileSnapshot.hasError) {
                  return _buildProfileLoadingFailed(
                    context,
                    profileSnapshot.error,
                  );
                }

                final profileDoc = profileSnapshot.data;

                if (profileDoc == null || !profileDoc.exists) {
                  return _buildProfileNotFound(context, refreshedUser);
                }

                final data = profileDoc.data() ?? {};
                final status = (data['status'] ?? 'pending')
                    .toString()
                    .trim()
                    .toLowerCase();

                switch (status) {
                  case 'approved':
                    return const MainHubScreen();

                  case 'blocked':
                    return const BlockedScreen();

                  case 'rejected':
                    return _buildRejectedScreen(context);

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
      error: (err, stack) => _buildAuthError(context, err),
    );
  }
}