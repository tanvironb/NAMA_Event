import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/speaker/screen/widgets/analytics_card.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Speaker Analytics Dashboard
/// Displays key metrics about speaker's sessions and engagement
class SpeakerAnalyticsScreen extends ConsumerWidget {
  const SpeakerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: allSessionsAsync.when(
        data: (allSessions) {
          // Filter sessions where current user is a speaker
          final mySessions = allSessions.where((s) => s.speakerIds.contains(userId)).toList();
          
          // Calculate analytics
          final totalSessions = mySessions.length;
          final upcomingSessions = mySessions.where((s) => s.startTime.isAfter(DateTime.now())).length;
          final completedSessions = mySessions.where((s) => s.endTime.isBefore(DateTime.now())).length;
          
          // TODO: Implement actual attendee counting from Firestore
          // For now, using placeholder values
          final totalAttendees = 0; // Will be calculated from session check-ins
          final avgAttendance = totalSessions > 0 ? (totalAttendees / totalSessions).toStringAsFixed(1) : '0';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Text(
                  'Your Performance',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your sessions and audience engagement',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.namaMediumGray,
                  ),
                ),
                const SizedBox(height: 24),

                // Session Statistics
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    AnalyticsCard(
                      icon: Icons.mic_external_on_outlined,
                      title: 'Total Sessions',
                      value: '$totalSessions',
                      iconColor: AppColors.namaNavyBlue,
                    ),
                    AnalyticsCard(
                      icon: Icons.schedule_outlined,
                      title: 'Upcoming',
                      value: '$upcomingSessions',
                      iconColor: AppColors.namaGoldenYellow,
                    ),
                    AnalyticsCard(
                      icon: Icons.check_circle_outline,
                      title: 'Completed',
                      value: '$completedSessions',
                      iconColor: AppColors.successGreen,
                    ),
                    AnalyticsCard(
                      icon: Icons.people_outline,
                      title: 'Avg. Attendance',
                      value: avgAttendance,
                      iconColor: AppColors.infoBlue,
                      subtitle: 'per session',
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Engagement Metrics (Placeholder)
                Text(
                  'Engagement Insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 48,
                          color: AppColors.namaNavyBlue.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Detailed Analytics Coming Soon',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Track session ratings, Q&A engagement, resource downloads, and more',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.namaMediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // TODO: Add more analytics features
                // - Session ratings/feedback summary
                // - Audience demographics
                // - Resource download stats
                // - Q&A participation rates
                // - Time-based attendance trends
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Text('Error loading analytics: $err'),
        ),
      ),
    );
  }
}
