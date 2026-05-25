import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/calendar/screens/my_calendar_screen.dart';
import 'package:events_app_trueattempt/features/meetings/screen/my_meetings_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';
import 'package:events_app_trueattempt/features/settings/screen/settings_screen.dart';

class ProfileTabScreen extends ConsumerWidget {
  final bool hideCalendarAndMeetings;

  const ProfileTabScreen({
    super.key,
    this.hideCalendarAndMeetings = false,
  });

  static const Color primaryColor = Color(0xFF24158A);

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

            final profileImageUrl = appUser.profileImageUrl.trim();
            final canGoBack = Navigator.of(context).canPop();

            final userRole = appUser.role.toLowerCase().trim();

            // Admin and staff should NOT see My Calendar or My Meetings.
            final shouldHideCalendarAndMeetings =
                hideCalendarAndMeetings ||
                userRole == 'staff' ||
                userRole == 'admin';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Row(
                    children: [
                      if (canGoBack) ...[
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F2FB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: primaryColor,
                              size: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        'Profile',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: primaryColor,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _showProfileImage(context, profileImageUrl);
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
                              backgroundImage: profileImageUrl.isNotEmpty
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                              backgroundColor: AppColors.avatarPlaceholder,
                              child: profileImageUrl.isEmpty
                                  ? const Icon(
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

                        if (!shouldHideCalendarAndMeetings) ...[
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
                            icon: Icons.groups_2_outlined,
                            title: 'My Meetings',
                            subtitle: 'View meeting requests and schedule',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MyMeetingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],

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
                                builder: (_) => const SettingsScreen(),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 6,
        ),
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
                color: AppColors.textPrimary,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 22,
          color: AppColors.namaMediumGray,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showProfileImage(BuildContext context, String imageUrl) {
    if (imageUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No profile picture available'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final previewSize = screenWidth > 420 ? 320.0 : screenWidth * 0.78;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              width: previewSize,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;

                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.avatarPlaceholder,
                            child: const Icon(
                              Icons.person,
                              size: 70,
                              color: AppColors.avatarPlaceholderText,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}