// lib/features/settings/screen/settings_screen.dart
import 'package:events_app_trueattempt/features/connections/screen/connections_screen.dart';
import 'package:events_app_trueattempt/features/settings/screen/about_event_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/help/screen/help_center_screen.dart';
import 'package:events_app_trueattempt/features/meetings/screen/my_meetings_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.55;

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
              _buildItem(
                icon: Icons.event,
                title: 'My Meeting',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyMeetingsScreen(),
                    ),
                  );
                },
              ),
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
              const SizedBox(height: 90),
              Center(
                child: SizedBox(
                  width: buttonWidth.clamp(170.0, 240.0),
                  child: _buildLogoutButton(),
                ),
              ),
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
          border: Border(
            bottom: BorderSide(
              color: Colors.black.withOpacity(0.25),
              width: 0.6,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 20,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTapDown: (_) => _scale.value = 0.96,
      onTapUp: (_) => _scale.value = 1,
      onTapCancel: () => _scale.value = 1,
      child: ValueListenableBuilder<double>(
        valueListenable: _scale,
        builder: (context, value, child) {
          return AnimatedScale(
            scale: value,
            duration: const Duration(milliseconds: 120),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _logout,
                  child: const Center(
                    child: Text(
                      'Log Out',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}