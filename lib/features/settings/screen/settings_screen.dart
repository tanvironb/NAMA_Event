// lib/features/settings/screen/settings_screen.dart

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_gate.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/certificates/screen/my_certificates_screen.dart';
import 'package:events_app_trueattempt/features/connections/screen/connections_screen.dart';
import 'package:events_app_trueattempt/features/privacy/screens/privacy_screen.dart';
import 'package:events_app_trueattempt/features/settings/screen/about_event_screen.dart';
import 'package:events_app_trueattempt/features/settings/screen/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoggingOut = false;

  bool _canSeeCertificates(String? role) {
    final cleanRole = (role ?? '').trim().toLowerCase();

    return cleanRole == 'attendee' || cleanRole == 'speaker';
  }

  bool _canSeeConnections(String? role) {
    final cleanRole = (role ?? '').trim().toLowerCase();

    return cleanRole == 'attendee' ||
        cleanRole == 'speaker' ||
        cleanRole == 'staff';
  }

  Future<void> _openDeleteAccount() async {
    if (_isLoggingOut) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DeleteAccountScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    final confirmed = await _showLogoutDialog();

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await ref.read(authViewModelProvider.notifier).signOut();

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const AuthGate(),
        ),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Logout failed: $error'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
    }
  }

  Future<bool?> _showLogoutDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            14,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.namaMediumGray,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
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
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userAppProfileStreamProvider);
    final role = userAsync.asData?.value?.role;

    final showCertificates = _canSeeCertificates(role);
    final showConnections = _canSeeConnections(role);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (showCertificates)
                      _SettingsTile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'My Certificates',
                        onTap: _isLoggingOut
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const MyCertificatesScreen(),
                                  ),
                                );
                              },
                      ),
                    if (showConnections)
                      _SettingsTile(
                        icon: Icons.people_outline_rounded,
                        title: 'Connections',
                        onTap: _isLoggingOut
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const ConnectionsScreen(),
                                  ),
                                );
                              },
                      ),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About Event',
                      onTap: _isLoggingOut
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const AboutEventScreen(),
                                ),
                              );
                            },
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy',
                      onTap: _isLoggingOut
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const PrivacyScreen(),
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel(
                      title: 'Account',
                    ),
                    const SizedBox(height: 8),
                    _SettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your account and data',
                      iconColor: Colors.red,
                      titleColor: Colors.red,
                      arrowColor: Colors.red,
                      onTap: _isLoggingOut
                          ? null
                          : _openDeleteAccount,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildLogoutButton(),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        InkWell(
          onTap: _isLoggingOut
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          borderRadius: BorderRadius.circular(10),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.arrow_back,
              size: 22,
              color: AppColors.namaNavyBlue,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.namaNavyBlue,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.55,
      height: 44,
      child: ElevatedButton(
        onPressed: _isLoggingOut ? null : _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          disabledBackgroundColor: Colors.red.shade300,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.red.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoggingOut
              ? const SizedBox(
                  key: ValueKey<String>('loading'),
                  height: 19,
                  width: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Log Out',
                  key: ValueKey<String>('text'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.namaMediumGray,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;
  final Color? arrowColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.arrowColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor =
        iconColor ?? AppColors.namaNavyBlue;
    final resolvedTitleColor =
        titleColor ?? AppColors.namaMediumGray;
    final resolvedArrowColor =
        arrowColor ?? AppColors.namaMediumGray;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: BoxConstraints(
          minHeight: subtitle == null ? 48 : 60,
        ),
        decoration: BoxDecoration(
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
              color: resolvedIconColor,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: resolvedTitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (subtitle != null &&
                        subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.namaMediumGray,
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward,
              size: 22,
              color: resolvedArrowColor,
            ),
          ],
        ),
      ),
    );
  }
}
