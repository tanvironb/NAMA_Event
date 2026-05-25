// lib/features/settings/screen/settings_screen.dart

import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/certificates/screen/my_certificates_screen.dart';
import 'package:events_app_trueattempt/features/connections/screen/connections_screen.dart';
import 'package:events_app_trueattempt/features/settings/screen/about_event_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/help/screen/help_center_screen.dart';
import 'package:events_app_trueattempt/features/privacy/screens/privacy_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ValueNotifier<double> _scale = ValueNotifier(1);

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await _showLogoutDialog(context);

    if (confirmed != true) return;

    await ref.read(authViewModelProvider.notifier).signOut();

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  bool _canSeeCertificates(String? role) {
    final cleanRole = (role ?? '').trim().toLowerCase();

    return cleanRole == 'attendee' || cleanRole == 'speaker';
  }

  bool _canSeeConnections(String? role) {
    final cleanRole = (role ?? '').trim().toLowerCase();

    // Connections should show for staff, attendee, and speaker.
    return cleanRole == 'staff' ||
        cleanRole == 'attendee' ||
        cleanRole == 'speaker';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.55;

    final userAsync = ref.watch(userAppProfileStreamProvider);

    final userRole = userAsync.asData?.value?.role;
    final showCertificates = _canSeeCertificates(userRole);
    final showConnections = _canSeeConnections(userRole);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.namaNavyBlue,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (showCertificates)
                _buildItem(
                  icon: Icons.workspace_premium_outlined,
                  title: 'My Certificates',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyCertificatesScreen(),
                      ),
                    );
                  },
                ),

              if (showConnections)
                _buildItem(
                  icon: Icons.people_outline,
                  title: 'Connections',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConnectionsScreen(),
                      ),
                    );
                  },
                ),

              _buildItem(
                icon: Icons.info_outline_rounded,
                title: 'About Event',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AboutEventScreen(),
                    ),
                  );
                },
              ),

              _buildItem(
                icon: Icons.lock_outline,
                title: 'Privacy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyScreen(),
                    ),
                  );
                },
              ),

              _buildItem(
                icon: Icons.help_outline,
                title: 'Help Centre',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpCenterScreen(),
                    ),
                  );
                },
              ),

              const Spacer(),

              Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: _scale,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: GestureDetector(
                        onTapDown: (_) => _scale.value = 0.96,
                        onTapCancel: () => _scale.value = 1,
                        onTapUp: (_) {
                          _scale.value = 1;
                          _logout();
                        },
                        child: Container(
                          width: buttonWidth,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.2),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 230),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppColors.namaMediumGray.withOpacity(0.25),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.namaNavyBlue,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.namaNavyBlue,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.namaMediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}