import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_analytics_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_audience_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_qa_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_resources_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Speaker Dashboard Screen
/// Redesigned to match the attendee-style quick actions interface.
class SpeakerDashboardScreen extends ConsumerWidget {
  const SpeakerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAppProfileStreamProvider).asData?.value;
    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    final upcomingSessionsCount = allSessionsAsync.when(
      data: (sessions) => sessions
          .where(
            (s) =>
                s.speakerIds.contains(user?.uid) &&
                s.startTime.isAfter(DateTime.now()),
          )
          .length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top logo + icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    AppConstants.logoCombinationPath,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return Icon(
                        Icons.auto_awesome,
                        color: AppColors.namaNavyBlue,
                        size: 32,
                      );
                    },
                  ),
                  Row(
                    children: [
                      _TopCircleButton(
                        icon: Icons.chat_bubble_outline,
                        onTap: () {},
                      ),
                      const SizedBox(width: 10),
                      _TopCircleButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Welcome text
              Text(
                'Hi, ${user?.name ?? 'Speaker'}!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.namaNavyBlue,
                      fontSize: 24,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Philanthropy Learning Forum',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.namaMediumGray,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
              ),

              if (upcomingSessionsCount > 0) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        color: AppColors.namaNavyBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$upcomingSessionsCount upcoming session${upcomingSessionsCount != 1 ? 's' : ''} scheduled',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.namaNavyBlue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 34),

              Row(
                children: [
                  Icon(
                    Icons.bolt,
                    color: AppColors.namaNavyBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF202124),
                          fontSize: 20,
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3.15,
                ),
                children: [
                  _QuickActionTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'My Sessions',
                    iconColor: AppColors.namaNavyBlue,
                    backgroundColor: const Color(0xFFEFF3FF),
                    isEnabled: remoteConfig.isSpeakerQRGenerationEnabled,
                    disabledMessage: 'Disabled',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MySessionsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.analytics_outlined,
                    title: 'Analytics',
                    iconColor: AppColors.namaGoldenYellow,
                    backgroundColor: const Color(0xFFF4EEFF),
                    isEnabled: remoteConfig.isSpeakerAnalyticsEnabled,
                    disabledMessage: 'Disabled',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SpeakerAnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Audience',
                    iconColor: AppColors.successGreen,
                    backgroundColor: const Color(0xFFEFFFF8),
                    isEnabled: remoteConfig.isSpeakerAudienceInsightsEnabled,
                    disabledMessage: 'Disabled',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SpeakerAudienceScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.star_border_rounded,
                    title: 'Feedback',
                    iconColor: AppColors.namaRichGold,
                    backgroundColor: const Color(0xFFFFF7EA),
                    isEnabled: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SessionFeedbackScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.question_answer_outlined,
                    title: 'Q&A',
                    iconColor: AppColors.namaMediumGray,
                    backgroundColor: const Color(0xFFFFEEF3),
                    isEnabled: false,
                    disabledMessage: 'Disabled',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SessionQAScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.folder_outlined,
                    title: 'Resources',
                    iconColor: AppColors.infoBlue,
                    backgroundColor: const Color(0xFFEFFFFF),
                    isEnabled: false,
                    disabledMessage: 'Disabled',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SessionResourcesScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.person_outline_rounded,
                    title: 'My Profile',
                    iconColor: AppColors.namaNavyBlue,
                    backgroundColor: const Color(0xFFF5F1FF),
                    isEnabled: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileTabScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'QR Scanner',
                    iconColor: AppColors.namaMediumGray,
                    backgroundColor: const Color(0xFFF1F4F7),
                    isEnabled: true,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          width: 40,
          child: Icon(
            icon,
            color: const Color(0xFF202124),
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color backgroundColor;
  final bool isEnabled;
  final String? disabledMessage;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.backgroundColor,
    required this.isEnabled,
    required this.onTap,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor =
        isEnabled ? iconColor : AppColors.namaMediumGray.withOpacity(0.45);

    final effectiveTextColor = isEnabled
        ? const Color(0xFF202124)
        : AppColors.namaMediumGray.withOpacity(0.55);

    return Material(
      color: isEnabled ? backgroundColor : const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isEnabled
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(disabledMessage ?? 'This feature is disabled'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: effectiveIconColor,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: effectiveTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: effectiveIconColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}