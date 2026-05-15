import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Speaker Analytics Dashboard
/// Displays key metrics about speaker's sessions and engagement.
class SpeakerAnalyticsScreen extends ConsumerWidget {
  const SpeakerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            // Static custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 18, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.namaNavyBlue,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Analytics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.namaNavyBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: allSessionsAsync.when(
                data: (allSessions) {
                  final mySessions = allSessions
                      .where((s) => s.speakerIds.contains(userId))
                      .toList();

                  final totalSessions = mySessions.length;

                  final upcomingSessions = mySessions
                      .where((s) => s.startTime.isAfter(DateTime.now()))
                      .length;

                  final completedSessions = mySessions
                      .where((s) => s.endTime.isBefore(DateTime.now()))
                      .length;

                  final totalAttendees = mySessions.fold<int>(
                    0,
                    (sum, session) =>
                        sum + session.checkedInAttendees.length,
                  );

                  final avgAttendance = totalSessions > 0
                      ? (totalAttendees / totalSessions).toStringAsFixed(1)
                      : '0.0';

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

                  final totalFeedbacks = mySessions.fold<int>(
                    0,
                    (sum, session) => sum + session.totalFeedbacks,
                  );

                  final sessionsWithFeedback =
                      mySessions.where((s) => s.totalFeedbacks > 0).toList();

                  final avgRating = sessionsWithFeedback.isEmpty
                      ? '0.0'
                      : (sessionsWithFeedback.fold<double>(
                                  0, (sum, s) => sum + s.averageRating) /
                              sessionsWithFeedback.length)
                          .toStringAsFixed(1);

                  final avgEngagementRate = totalSessions > 0
                      ? (mySessions.fold<double>(
                                  0, (sum, s) => sum + s.engagementRate) /
                              totalSessions)
                          .toStringAsFixed(1)
                      : '0.0';

                  final feedbackResponseRate = totalAttendees > 0
                      ? ((totalFeedbacks / totalAttendees) * 100)
                          .toStringAsFixed(1)
                      : '0';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Performance',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.namaNavyBlue,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Track your sessions, audience engagement, and feedback',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.namaMediumGray,
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                        ),

                        const SizedBox(height: 22),

                        _SectionTitle(title: 'Session Overview'),
                        const SizedBox(height: 12),
                        _CompactGrid(
                          children: [
                            _CompactAnalyticsCard(
                              icon: Icons.mic_external_on_outlined,
                              title: 'Total Sessions',
                              value: '$totalSessions',
                              iconColor: AppColors.namaNavyBlue,
                            ),
                            _CompactAnalyticsCard(
                              icon: Icons.schedule_outlined,
                              title: 'Upcoming',
                              value: '$upcomingSessions',
                              iconColor: AppColors.namaGoldenYellow,
                            ),
                            _CompactAnalyticsCard(
                              icon: Icons.check_circle_outline,
                              title: 'Completed',
                              value: '$completedSessions',
                              iconColor: AppColors.successGreen,
                            ),
                            _CompactAnalyticsCard(
                              icon: Icons.people_outline,
                              title: 'Avg. Attendance',
                              value: avgAttendance,
                              iconColor: AppColors.infoBlue,
                              subtitle: 'per session',
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        _SectionTitle(title: 'Chat Engagement'),
                        const SizedBox(height: 12),
                        _CompactGrid(
                          children: [
                            _CompactAnalyticsCard(
                              icon: Icons.chat_bubble_outline,
                              title: 'Total Messages',
                              value: '$totalMessages',
                              iconColor: AppColors.infoBlue,
                            ),
                            _CompactAnalyticsCard(
                              icon: Icons.group_outlined,
                              title: 'Participants',
                              value: '$totalUniqueParticipants',
                              iconColor: AppColors.successGreen,
                              subtitle: 'unique users',
                            ),
                            _CompactAnalyticsCard(
                              icon: Icons.percent_outlined,
                              title: 'Engagement Rate',
                              value: '$avgEngagementRate%',
                              iconColor: AppColors.namaGoldenYellow,
                              subtitle: 'avg across sessions',
                            ),
                            _CompactAnalyticsCard(
                              icon: Icons.delete_outline,
                              title: 'Deleted Messages',
                              value: '$totalDeletedMessages',
                              iconColor: AppColors.errorRed,
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        _SectionTitle(title: 'Moderation Activity'),
                        const SizedBox(height: 12),
                        _CompactAnalyticsCard(
                          icon: Icons.volume_off_outlined,
                          title: 'Mute Actions',
                          value: '$totalMuteActions',
                          iconColor: AppColors.warningAmber,
                          fullWidth: true,
                        ),

                        const SizedBox(height: 22),

                        _SectionTitle(title: 'Session Feedback'),
                        const SizedBox(height: 12),
                        _CompactGrid(
                          children: [
                            _CompactAnalyticsCard(
                              icon: Icons.feedback_outlined,
                              title: 'Total Feedback',
                              value: '$totalFeedbacks',
                              iconColor: AppColors.namaNavyBlue,
                            ),
                            _CompactAnalyticsCard(
                              icon: Icons.star_outline,
                              title: 'Average Rating',
                              value: avgRating,
                              iconColor: AppColors.namaGoldenYellow,
                              subtitle: 'out of 5.0',
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        _QuickInsightsCard(
                          totalAttendees: '$totalAttendees',
                          avgEngagementRate: '$avgEngagementRate%',
                          feedbackResponseRate: '$feedbackResponseRate%',
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading analytics: $err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.namaNavyBlue,
          ),
    );
  }
}

class _CompactGrid extends StatelessWidget {
  final List<Widget> children;

  const _CompactGrid({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: children,
    );
  }
}

class _CompactAnalyticsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final String? subtitle;
  final bool fullWidth;

  const _CompactAnalyticsCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
    this.subtitle,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.namaMediumGray,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.namaNavyBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.namaMediumGray,
                    fontSize: 10.5,
                    height: 1,
                  ),
            ),
          ],
        ],
      ),
    );

    if (fullWidth) {
      return SizedBox(
        height: 96,
        child: card,
      );
    }

    return card;
  }
}

class _QuickInsightsCard extends StatelessWidget {
  final String totalAttendees;
  final String avgEngagementRate;
  final String feedbackResponseRate;

  const _QuickInsightsCard({
    required this.totalAttendees,
    required this.avgEngagementRate,
    required this.feedbackResponseRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_outlined,
                color: AppColors.namaNavyBlue,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Insights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.namaNavyBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InsightRow(
            icon: Icons.people_alt_outlined,
            label: 'Total attendees across all sessions',
            value: totalAttendees,
          ),
          const Divider(height: 18),
          _InsightRow(
            icon: Icons.trending_up_outlined,
            label: 'Average engagement rate',
            value: avgEngagementRate,
          ),
          const Divider(height: 18),
          _InsightRow(
            icon: Icons.rate_review_outlined,
            label: 'Feedback response rate',
            value: feedbackResponseRate,
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: AppColors.namaMediumGray,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.namaDarkGray,
                  fontSize: 12.5,
                  height: 1.2,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.namaNavyBlue,
              ),
        ),
      ],
    );
  }
}