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

    final currentVisibility = ProfileVisibility.fromString(currentUser.profileVisibility);
    final scannedByCount = currentUser.scannedByUsers.length;

    // Show warning if changing from Full to Anonymous/Minimal and users have scanned them
    bool shouldShowWarning = (currentVisibility == ProfileVisibility.full) && 
                              scannedByCount > 0;

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

    // Show privacy selection dialog
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
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

      // Refresh user data
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

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(firebaseAuthProvider).signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      appBar: AppBar(
        title: const Text('Privacy & Settings'),
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          final currentVisibility = ProfileVisibility.fromString(user.profileVisibility);
          final scannedByCount = user.scannedByUsers.length;
          final usersIScannedCount = user.usersIScanned.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Privacy Section
                _buildSectionHeader('Privacy Level'),
                const SizedBox(height: 8),
                _buildCurrentPrivacyCard(currentVisibility),
                const SizedBox(height: 16),
                
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _changePrivacyLevel,
                  icon: const Icon(AppIcons.edit),
                  label: const Text('Change Privacy Level'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Connection Stats
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
                const SizedBox(height: 24),
                
                // Account Section
                _buildSectionHeader('Account'),
                const SizedBox(height: 8),
                
                // Change Password Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                  icon: const Icon(AppIcons.lock),
                  label: const Text('Change Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // App Info Section
                _buildSectionHeader('Application'),
                const SizedBox(height: 8),
                _buildInfoCard(
                  icon: AppIcons.info,
                  title: 'App Version',
                  value: _appVersion,
                ),
                const SizedBox(height: 16),
                
                // Logout Button
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(AppIcons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.namaNavyBlue,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildCurrentPrivacyCard(ProfileVisibility level) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.namaNavyBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                level.icon,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.namaNavyBlue,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  level.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      padding: const EdgeInsets.all(16),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }
}
