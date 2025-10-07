// lib/common_widgets/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Company logo
            Image.asset(
              AppConstants.logoCombinationPath, 
              height: 80, 
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 40),
            const LoadingIndicator(),
            const SizedBox(height: 16),
            Text(
              'Initializing Event...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}