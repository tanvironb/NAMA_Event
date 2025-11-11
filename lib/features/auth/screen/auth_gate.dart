import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/auth/screen/login_screen.dart';
import 'package:events_app_trueattempt/features/auth/screen/email_verification_screen.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/main_hub/screen/main_hub_screen.dart';
import 'package:events_app_trueattempt/features/auth/screen/pending_approval_screen.dart';
import 'package:events_app_trueattempt/features/auth/screen/blocked_screen.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';

// AuthGate handles the initial routing based on user's authentication state.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user != null && user.email != null) {
          // Check if email is verified first
          if (!user.emailVerified) {
            return const EmailVerificationScreen();
          }
          
          // User is authenticated and verified - check their profile and status
          final userProfileAsync = ref.watch(userAppProfileStreamProvider);
          return userProfileAsync.when(
            data: (appUser) {
              if (appUser == null) {
                // User authenticated but no profile found
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 16),
                        Text('Profile Not Found', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text('Your account profile could not be loaded.'),
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

              // Check user status
              switch (appUser.status) {
                case 'approved':
                  return const MainHubScreen();
                case 'rejected':
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block, size: 64, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Text('Access Denied', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text('Your account has been rejected.'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ),
                  );
                case 'blocked':
                  return const BlockedScreen();
                case 'pending':
                default:
                  return const PendingApprovalScreen();
              }
            },
            loading: () => const Scaffold(body: LoadingIndicator()),
            error: (err, stack) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text('Error', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Failed to load profile: $err'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // User is not authenticated - show login
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: LoadingIndicator(), // Show a loading spinner while checking auth state
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Authentication Error', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('$err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(authStateChangesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}