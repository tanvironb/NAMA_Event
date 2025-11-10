// lib/features/auth/screen/blocked_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Screen shown to users whose status is 'blocked'
/// They cannot access the app and must contact administrators
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block,
                  size: 80,
                  color: AppColors.errorRed,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Account Blocked',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.namaNavyBlue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Your account has been blocked by an administrator.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.namaDarkGray,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'If you believe this is a mistake, please contact the event organizers for assistance.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.namaMediumGray,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Contact Info Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.support_agent,
                        size: 40,
                        color: AppColors.namaNavyBlue,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Need Help?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Contact event support',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.namaMediumGray,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'support@namafoundation.org',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.namaNavyBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authViewModelProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: AppColors.namaWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
