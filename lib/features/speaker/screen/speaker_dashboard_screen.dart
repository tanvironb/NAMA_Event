import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_analytics_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_audience_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_qa_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_resources_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/widgets/dashboard_action_card.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Enhanced Speaker Dashboard Screen
/// Provides comprehensive tools and insights for speakers
/// Features are controlled via Firebase Remote Config
class SpeakerDashboardScreen extends ConsumerWidget {
  const SpeakerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAppProfileStreamProvider).asData?.value;
    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    // Get quick stats for the header
    final upcomingSessionsCount = allSessionsAsync.when(
      data: (sessions) => sessions
          .where((s) => 
            s.speakerIds.contains(user?.uid) && 
            s.startTime.isAfter(DateTime.now())
          )
          .length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              'Welcome, ${user?.name ?? 'Speaker'}!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Speaker Dashboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.namaMediumGray,
              ),
            ),

            // Quick Stats Banner
            if (upcomingSessionsCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upcoming Sessions',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '$upcomingSessionsCount session${upcomingSessionsCount != 1 ? 's' : ''} scheduled',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Quick Actions Section
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(height: 12),

            // My Sessions - Always available
            DashboardActionCard(
              icon: Icons.mic_external_on_outlined,
              title: 'My Sessions',
              subtitle: 'View details and generate QR codes for your sessions',
              iconColor: AppColors.namaNavyBlue,
              isEnabled: remoteConfig.isSpeakerQRGenerationEnabled,
              disabledMessage: 'Session management is currently disabled',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const MySessionsScreen(),
                ));
              },
            ),

            const SizedBox(height: 12),

            // Analytics - Controlled by remote config
            DashboardActionCard(
              icon: Icons.analytics_outlined,
              title: 'Analytics',
              subtitle: 'Track your performance and session insights',
              iconColor: AppColors.namaGoldenYellow,
              isEnabled: remoteConfig.isSpeakerAnalyticsEnabled,
              disabledMessage: 'Analytics is currently unavailable',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SpeakerAnalyticsScreen(),
                ));
              },
            ),

            const SizedBox(height: 12),

            // My Audience - Controlled by remote config
            DashboardActionCard(
              icon: Icons.people_outline,
              title: 'My Audience',
              subtitle: 'Connect with attendees interested in your sessions',
              iconColor: AppColors.infoBlue,
              isEnabled: remoteConfig.isSpeakerAudienceInsightsEnabled,
              disabledMessage: 'Audience insights is currently unavailable',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SpeakerAudienceScreen(),
                ));
              },
            ),

            const SizedBox(height: 24),

            // Tools & Resources Section
            Text(
              'Tools & Resources',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(height: 12),

            // Session Q&A - Placeholder (Will be controlled by session chat when implemented)
            DashboardActionCard(
              icon: Icons.question_answer_outlined,
              title: 'Session Q&A',
              subtitle: 'Manage questions from attendees (Coming Soon)',
              iconColor: AppColors.namaMediumGray,
              isEnabled: false, // Always disabled until backend is ready
              disabledMessage: 'Q&A feature is under development',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SessionQAScreen(),
                ));
              },
            ),

            const SizedBox(height: 12),

            // My Resources - Placeholder
            DashboardActionCard(
              icon: Icons.folder_outlined,
              title: 'My Resources',
              subtitle: 'Upload and share session materials (Coming Soon)',
              iconColor: AppColors.namaRichGold,
              isEnabled: false, // Always disabled for now - no remote config yet
              disabledMessage: 'Resource management is under development',
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SessionResourcesScreen(),
                ));
              },
            ),

            const SizedBox(height: 12),

            // Session Feedback
            DashboardActionCard(
              icon: Icons.rate_review_outlined,
              title: 'Session Feedback',
              subtitle: 'View ratings and reviews from attendees',
              iconColor: AppColors.successGreen,
              isEnabled: true,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SessionFeedbackScreen(),
                ));
              },
            ),

            const SizedBox(height: 24),

            // Profile Section
            Text(
              'Profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(height: 12),

            // My Public Profile
            DashboardActionCard(
              icon: Icons.person_outline,
              title: 'My Public Profile',
              subtitle: 'View and edit how attendees see your profile',
              iconColor: AppColors.namaNavyBlue,
              isEnabled: true,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const ProfileTabScreen(),
                ));
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}