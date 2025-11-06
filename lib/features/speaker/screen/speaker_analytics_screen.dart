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
          
          // Calculate session analytics
          final totalSessions = mySessions.length;
          final upcomingSessions = mySessions.where((s) => s.startTime.isAfter(DateTime.now())).length;
          final completedSessions = mySessions.where((s) => s.endTime.isBefore(DateTime.now())).length;
          
          // Calculate attendee analytics
          final totalAttendees = mySessions.fold<int>(
            0,
            (sum, session) => sum + session.checkedInAttendees.length,
          );
          final avgAttendance = totalSessions > 0 
            ? (totalAttendees / totalSessions).toStringAsFixed(1) 
            : '0';

          // Calculate chat analytics
          final totalMessages = mySessions.fold<int>(
            0,
            (sum, session) => sum + session.totalMessages,
          );
          final totalUniqueParticipants = mySessions
            .expand((s) => s.uniqueParticipants)
            .toSet()
            .length;
          final totalDeletedMessages = mySessions.fold<int>(
            0,
            (sum, session) => sum + session.deletedMessagesCount,
          );
          final totalMuteActions = mySessions.fold<int>(
            0,
            (sum, session) => sum + session.totalMuteActions,
          );

          // Calculate feedback analytics
          final totalFeedbacks = mySessions.fold<int>(
            0,
            (sum, session) => sum + session.totalFeedbacks,
          );
          final avgRating = mySessions.where((s) => s.totalFeedbacks > 0).isEmpty
            ? '0.0'
            : (mySessions
                .where((s) => s.totalFeedbacks > 0)
                .fold<double>(0, (sum, s) => sum + s.averageRating) /
                mySessions.where((s) => s.totalFeedbacks > 0).length)
                .toStringAsFixed(1);

          // Calculate engagement rate (average across all sessions)
          final avgEngagementRate = totalSessions > 0
            ? (mySessions.fold<double>(0, (sum, s) => sum + s.engagementRate) / totalSessions)
                .toStringAsFixed(1)
            : '0.0';

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
                  'Track your sessions, audience engagement, and feedback',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.namaMediumGray,
                  ),
                ),
                const SizedBox(height: 24),

                // Session Statistics
                Text(
                  'Session Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 12),
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

                const SizedBox(height: 24),

                // Chat Analytics
                Text(
                  'Chat Engagement',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    AnalyticsCard(
                      icon: Icons.chat_bubble_outline,
                      title: 'Total Messages',
                      value: '$totalMessages',
                      iconColor: AppColors.infoBlue,
                    ),
                    AnalyticsCard(
                      icon: Icons.group_outlined,
                      title: 'Participants',
                      value: '$totalUniqueParticipants',
                      iconColor: AppColors.successGreen,
                      subtitle: 'unique users',
                    ),
                    AnalyticsCard(
                      icon: Icons.percent_outlined,
                      title: 'Engagement Rate',
                      value: '$avgEngagementRate%',
                      iconColor: AppColors.namaGoldenYellow,
                      subtitle: 'avg across sessions',
                    ),
                    AnalyticsCard(
                      icon: Icons.delete_outline,
                      title: 'Deleted Messages',
                      value: '$totalDeletedMessages',
                      iconColor: AppColors.errorRed,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Moderation Analytics
                Text(
                  'Moderation Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AnalyticsCard(
                        icon: Icons.volume_off_outlined,
                        title: 'Mute Actions',
                        value: '$totalMuteActions',
                        iconColor: AppColors.warningAmber,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Feedback Analytics
                Text(
                  'Session Feedback',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    AnalyticsCard(
                      icon: Icons.feedback_outlined,
                      title: 'Total Feedback',
                      value: '$totalFeedbacks',
                      iconColor: AppColors.namaNavyBlue,
                    ),
                    AnalyticsCard(
                      icon: Icons.star_outline,
                      title: 'Average Rating',
                      value: avgRating,
                      iconColor: AppColors.namaGoldenYellow,
                      subtitle: 'out of 5.0',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Detailed Breakdown Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.insights_outlined,
                              color: AppColors.namaNavyBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Quick Insights',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.namaNavyBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInsightRow(
                          context,
                          'Total attendees across all sessions',
                          '$totalAttendees',
                          Icons.people_alt_outlined,
                        ),
                        const Divider(height: 24),
                        _buildInsightRow(
                          context,
                          'Average engagement rate',
                          '$avgEngagementRate%',
                          Icons.trending_up_outlined,
                        ),
                        const Divider(height: 24),
                        _buildInsightRow(
                          context,
                          'Feedback response rate',
                          totalAttendees > 0
                            ? '${((totalFeedbacks / totalAttendees) * 100).toStringAsFixed(1)}%'
                            : '0%',
                          Icons.rate_review_outlined,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
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

  Widget _buildInsightRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.namaMediumGray,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.namaDarkGray,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.namaNavyBlue,
          ),
        ),
      ],
    );
  }
}
