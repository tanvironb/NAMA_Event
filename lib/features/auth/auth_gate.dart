import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/home/home_screen.dart';
import 'package:events_app_trueattempt/features/auth/login_screen.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}