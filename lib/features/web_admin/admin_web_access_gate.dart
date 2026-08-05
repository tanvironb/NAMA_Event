import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_web_login_screen.dart';
import 'admin_web_shell.dart';
import 'admin_web_theme.dart';

class AdminWebAccessGate extends StatelessWidget {
  const AdminWebAccessGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AdminWebLoadingScreen();
        }

        final firebaseUser = authSnapshot.data;

        if (firebaseUser == null) {
          return const AdminWebLoginScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _AdminWebLoadingScreen();
            }

            if (userSnapshot.hasError) {
              return _AdminWebErrorScreen(
                message: userSnapshot.error.toString(),
              );
            }

            final userDocument = userSnapshot.data;
            final userData = userDocument?.data();

            if (userDocument == null ||
                !userDocument.exists ||
                userData == null) {
              return const _AdminWebAccessDeniedScreen(
                title: 'Profile Not Found',
                message:
                    'Your Firebase account exists, but the corresponding user profile could not be found.',
              );
            }

            final role = (userData['role'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            final status = (userData['status'] ?? 'approved')
                .toString()
                .trim()
                .toLowerCase();

            if (role != 'admin') {
              return const _AdminWebAccessDeniedScreen(
                title: 'Admin Access Required',
                message:
                    'This website is restricted to NAMA Events administrators.',
              );
            }

            if (status == 'rejected' || status == 'disabled') {
              return const _AdminWebAccessDeniedScreen(
                title: 'Account Disabled',
                message:
                    'Your administrator account is currently disabled.',
              );
            }

            return AdminWebShell(
              adminUserId: firebaseUser.uid,
              adminName: (userData['name'] ?? 'Administrator').toString(),
              adminEmail: (userData['email'] ?? firebaseUser.email ?? '')
                  .toString(),
              profileImageUrl:
                  (userData['profileImageUrl'] ?? '').toString(),
            );
          },
        );
      },
    );
  }
}

class _AdminWebLoadingScreen extends StatelessWidget {
  const _AdminWebLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AdminWebTheme.background,
      body: Center(
        child: CircularProgressIndicator(
          color: AdminWebTheme.primary,
        ),
      ),
    );
  }
}

class _AdminWebErrorScreen extends StatelessWidget {
  final String message;

  const _AdminWebErrorScreen({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminWebTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AdminWebTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 52,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to Verify Account',
                  style: TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminWebAccessDeniedScreen extends StatelessWidget {
  final String title;
  final String message;

  const _AdminWebAccessDeniedScreen({
    required this.title,
    required this.message,
  });

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminWebTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AdminWebTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: AdminWebTheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AdminWebTheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Return to Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}