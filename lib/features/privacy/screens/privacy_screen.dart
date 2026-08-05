import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';
import 'package:events_app_trueattempt/core/enums/profile_visibility.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/privacy/widgets/privacy_selection_dialog.dart';
import 'package:events_app_trueattempt/features/privacy/screens/change_password_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  String _appVersion = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _changePrivacyLevel() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final currentUserAsync = ref.read(userAppProfileStreamProvider);
    final currentUser = currentUserAsync.value;
    if (currentUser == null) return;

    final currentVisibility =
        ProfileVisibility.fromString(currentUser.profileVisibility);
    final scannedByCount = currentUser.scannedByUsers.length;

    final shouldShowWarning =
        currentVisibility == ProfileVisibility.full && scannedByCount > 0;

    if (shouldShowWarning) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Privacy Level Change'),
          content: Text(
            '$scannedByCount users have scanned your QR code and will still see your data even after you change your privacy level.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PrivacySelectionDialog(
        initialSelection: currentVisibility,
        canDismiss: true,
        onConfirm: (selectedLevel) async {
          Navigator.pop(context);
          await _updatePrivacyLevel(selectedLevel);
        },
      ),
    );
  }

  Future<void> _updatePrivacyLevel(ProfileVisibility newLevel) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profileVisibility': newLevel.value,
        'privacySelectedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Privacy level updated to ${newLevel.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      ref.invalidate(userAppProfileStreamProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating privacy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      body: SafeArea(
        child: currentUserAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              'Error: $error',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          data: (user) {
            if (user == null) {
              return const Center(
                child: Text(
                  'User not found',
                  style: TextStyle(fontSize: 13),
                ),
              );
            }

            final currentVisibility =
                ProfileVisibility.fromString(user.profileVisibility);
            final scannedByCount = user.scannedByUsers.length;
            final usersIScannedCount = user.usersIScanned.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.namaNavyBlue,
                            size: 24,
                          ),
                        ),
                      ),
                      const Text(
                        'Privacy',
                        style: TextStyle(
                          color: AppColors.namaNavyBlue,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _buildSectionHeader('Privacy Level'),
                  const SizedBox(height: 8),
                  _buildCurrentPrivacyCard(currentVisibility),
                  const SizedBox(height: 14),

                  Center(
                    child: _buildSmallButton(
                      icon: AppIcons.edit,
                      text: 'Change Privacy Level',
                      onPressed: _isLoading ? null : _changePrivacyLevel,
                    ),
                  ),

                  const SizedBox(height: 26),

                  _buildSectionHeader('Connection Statistics'),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    icon: AppIcons.people,
                    title: 'Users who scanned you',
                    value: scannedByCount.toString(),
                    color: AppColors.namaGoldenYellow,
                  ),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    icon: AppIcons.qrCodeScanner,
                    title: 'Users you scanned',
                    value: usersIScannedCount.toString(),
                    color: AppColors.namaNavyBlue,
                  ),

                  const SizedBox(height: 26),

                  _buildSectionHeader('Account'),
                  const SizedBox(height: 10),

                  Center(
                    child: _buildSmallButton(
                      icon: AppIcons.lock,
                      text: 'Change Password',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 26),

                  _buildSectionHeader('Application'),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    icon: AppIcons.info,
                    title: 'App Version',
                    value: '1.0.1',
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.namaNavyBlue,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 260,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaNavyBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPrivacyCard(ProfileVisibility level) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.namaNavyBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.namaNavyBlue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.namaNavyBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                level.icon,
                style: const TextStyle(fontSize: 25),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  level.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey.shade600,
            size: 21,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}