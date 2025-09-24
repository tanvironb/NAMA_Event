import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/home/screen/home_screen.dart';
import 'package:events_app_trueattempt/features/auth/screen/login_screen.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

// AuthGate handles the initial routing based on user's authentication state.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user != null // If a user is logged in
          ? const HomeScreen() // Show the main app content
          : const LoginScreen(), // Otherwise, show the login screen
      loading: () => const Scaffold(
        body: LoadingIndicator(), // Show a loading spinner while checking auth state
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error: $err')), // Display any authentication errors
      ),
    );
  }
}