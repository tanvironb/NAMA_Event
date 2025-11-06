import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Speaker Audience Insights Screen
/// Shows attendees who bookmarked or checked into speaker's sessions
class SpeakerAudienceScreen extends ConsumerWidget {
  const SpeakerAudienceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Audience'),
      ),
      body: allSessionsAsync.when(
        data: (allSessions) {
          // Filter sessions where current user is a speaker
          final mySessions = allSessions.where((s) => s.speakerIds.contains(userId)).toList();

          if (mySessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppColors.namaMediumGray.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Sessions Yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.namaDarkGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see your audience once you\'re assigned to sessions',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.namaMediumGray,
                    ),
                  ),
                ],
              ),
            );
          }

          // Calculate audience stats
          final totalCheckedIn = mySessions.fold<int>(
            0,
            (sum, s) => sum + s.checkedInAttendees.length,
          );
          final uniqueAttendees = mySessions
            .expand((s) => s.checkedInAttendees)
            .toSet()
            .length;
          final totalParticipants = mySessions
            .expand((s) => s.uniqueParticipants)
            .toSet()
            .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Audience Insights',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect with attendees interested in your sessions',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.namaMediumGray,
                  ),
                ),
                const SizedBox(height: 24),

                // Summary Cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    Card(
                      elevation: 2,
                      color: AppColors.namaLightBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.how_to_reg_outlined,
                              size: 32,
                              color: AppColors.namaNavyBlue,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$uniqueAttendees',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.namaNavyBlue,
                              ),
                            ),
                            Text(
                              'Unique Attendees',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.namaDarkGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      color: AppColors.namaWarmGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner_outlined,
                              size: 32,
                              color: AppColors.namaRichGold,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$totalCheckedIn',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.namaRichGold,
                              ),
                            ),
                            Text(
                              'Total Check-ins',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.namaDarkGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 32,
                              color: AppColors.infoBlue,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$totalParticipants',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.infoBlue,
                              ),
                            ),
                            Text(
                              'Chat Participants',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.namaDarkGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.percent_outlined,
                              size: 32,
                              color: AppColors.successGreen,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              uniqueAttendees > 0
                                ? '${((totalParticipants / uniqueAttendees) * 100).toStringAsFixed(0)}%'
                                : '0%',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.successGreen,
                              ),
                            ),
                            Text(
                              'Engagement Rate',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.namaDarkGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Session-by-Session Breakdown
                Text(
                  'Session Breakdown',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 12),

                // List sessions with their stats
                ...mySessions.map((session) {
                  final engagementRate = session.engagementRate;
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Session title
                          Text(
                            session.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.namaNavyBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Stats row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 16,
                                          color: AppColors.namaMediumGray,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${session.checkedInAttendees.length}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.namaNavyBlue,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'attendees',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.namaMediumGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 16,
                                          color: AppColors.namaMediumGray,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${session.uniqueParticipants.length}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.infoBlue,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'chat participants',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.namaMediumGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: engagementRate >= 50
                                    ? AppColors.successGreen.withOpacity(0.1)
                                    : AppColors.warningAmber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${engagementRate.toStringAsFixed(0)}%',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: engagementRate >= 50
                                          ? AppColors.successGreen
                                          : AppColors.warningAmber,
                                      ),
                                    ),
                                    Text(
                                      'engagement',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: engagementRate >= 50
                                          ? AppColors.successGreen
                                          : AppColors.warningAmber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Text('Error loading audience data: $err'),
        ),
      ),
    );
  }
}
