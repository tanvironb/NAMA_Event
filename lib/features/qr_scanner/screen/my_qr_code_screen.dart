// lib/features/qr_scanner/screen/my_qr_code_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';
import 'package:events_app_trueattempt/core/enums/profile_visibility.dart';

class MyQRCodeScreen extends ConsumerWidget {
  const MyQRCodeScreen({super.key});

  /// Get QR background color based on user role
  Color _getQRBackgroundColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.qrAdminBackground;
      case 'staff':
        return AppColors.qrStaffBackground;
      case 'speaker':
        return AppColors.qrSpeakerBackground;
      case 'user':
      case 'attendee':
      default:
        return AppColors.qrAttendeeBackground;
    }
  }

  /// Get role display name for better UX
  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'staff':
        return 'Staff Member';
      case 'speaker':
        return 'Speaker';
      case 'user':
      case 'attendee':
      default:
        return 'Attendee';
    }
  }

  /// Get privacy-aware warning text based on user's privacy level
  String _getPrivacyAwareWarning(ProfileVisibility privacyLevel) {
    switch (privacyLevel) {
      case ProfileVisibility.anonymous:
        return 'Sharing this QR initiates a connection. They can view your Minimal profile and later your Full profile if you change your privacy settings.';
      case ProfileVisibility.minimal:
        return 'Sharing this QR initiates a connection. They can view your Minimal profile (name, company, role). They can view your Full profile if you later change to Full privacy.';
      case ProfileVisibility.full:
        return 'Sharing this QR initiates a connection. They can view your Full profile (all information). If you later change to Anonymous, they will still be able to view your Minimal profile.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: userProfileAsync.when(
          data: (user) {
            if (user == null || user.qrCodePayload.isEmpty) {
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.qrCode,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'QR Code Unavailable',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your QR code is being generated. Please check back shortly.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final backgroundColor = _getQRBackgroundColor(user.role);
            final roleDisplayName = _getRoleDisplayName(user.role);
            final privacyLevel = ProfileVisibility.fromString(user.profileVisibility);

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header
                Text(
                  'My QR Code',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  roleDisplayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Privacy Level Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: privacyLevel == ProfileVisibility.anonymous
                        ? AppColors.namaNavyBlue.withOpacity(0.1)
                        : privacyLevel == ProfileVisibility.minimal
                            ? AppColors.namaGoldenYellow.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: privacyLevel == ProfileVisibility.anonymous
                          ? AppColors.namaNavyBlue
                          : privacyLevel == ProfileVisibility.minimal
                              ? AppColors.namaGoldenYellow
                              : Colors.green,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        privacyLevel.icon,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Your privacy: ${privacyLevel.displayName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: privacyLevel == ProfileVisibility.anonymous
                              ? AppColors.namaNavyBlue
                              : privacyLevel == ProfileVisibility.minimal
                                  ? AppColors.namaGoldenYellow
                                  : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // QR Code Container with role-based background
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        // QR Code with Role-Based Background
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getQRBackgroundColor(user.role),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.namaNavyBlue.withOpacity(0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.namaNavyBlue.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Role Badge
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.namaNavyBlue,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _getRoleDisplayName(user.role),
                                  style: const TextStyle(
                                    color: AppColors.namaWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // QR Code
                              QrImageView(
                                data: user.qrCodePayload,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.transparent,
                                foregroundColor: AppColors.namaNavyBlue,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.namaNavyBlue,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.namaNavyBlue,
                                ),
                              ),
                              // QR Info Text
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.namaNavyBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Scan to connect with ${user.name}',
                                  style: TextStyle(
                                    color: AppColors.namaNavyBlue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // User Info
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (user.company.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.company,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Privacy-aware warning message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AppIcons.info,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getPrivacyAwareWarning(privacyLevel),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const LoadingIndicator(),
          error: (err, stack) => Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.error,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading QR Code',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Could not load your QR code. Please try again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}