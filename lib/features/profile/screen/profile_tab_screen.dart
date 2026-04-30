// lib/features/profile/screen/profile_tab_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/calendar/screens/my_calendar_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';
import 'package:events_app_trueattempt/features/settings/screen/settings_screen.dart';

class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: userProfileAsync.when(
          data: (appUser) {
            if (appUser == null) {
              return const Center(child: Text('Profile not found'));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: const Color(0xFF24158A),
                        ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _showProfileImage(context, appUser.profileImageUrl);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.namaGoldenYellow,
                                width: 2.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 54,
                              backgroundImage:
                                  appUser.profileImageUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          appUser.profileImageUrl,
                                        )
                                      : null,
                              backgroundColor: AppColors.avatarPlaceholder,
                              child: appUser.profileImageUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 54,
                                      color: AppColors.avatarPlaceholderText,
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        const SizedBox(height: 34),

                        _buildMenuItem(
                          context,
                          icon: Icons.person,
                          title: 'My Account',
                          subtitle: 'View and edit your profile',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserDetailsScreen(userId: appUser.uid),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        _buildMenuItem(
                          context,
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Manage notifications',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationsScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        _buildMenuItem(
                          context,
                          icon: Icons.calendar_month_outlined,
                          title: 'My Calendar',
                          subtitle: 'View your schedule',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MyCalendarScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                       _buildMenuItem(
  context,
  icon: Icons.settings_outlined,
  title: 'Settings',
  subtitle: 'App settings and preferences',
 onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) {
        return const SettingsScreen();
      },
    ),
  );
},
),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const LoadingIndicator(),
          error: (error, stack) => Center(
            child: Text('Error loading profile: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.navyBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.navyBlue,
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 22,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showProfileImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox(
                          height: 260,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.person, size: 120),
                      ),
                    )
                  : const SizedBox(
                      height: 260,
                      child: Center(
                        child: Icon(Icons.person, size: 120),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}