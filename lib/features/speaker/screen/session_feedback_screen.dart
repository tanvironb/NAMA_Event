import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Session Feedback Screen
/// Shows ratings and feedback from attendees for speaker's sessions
class SessionFeedbackScreen extends ConsumerWidget {
  const SessionFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Feedback'),
      ),
      body: allSessionsAsync.when(
        data: (allSessions) {
          // Filter completed sessions where current user is a speaker
          final mySessions = allSessions
              .where((s) => 
                s.speakerIds.contains(userId) && 
                s.endTime.isBefore(DateTime.now())
              )
              .toList();

          if (mySessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 64,
                      color: AppColors.namaMediumGray.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Completed Sessions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.namaDarkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Feedback will appear here after you complete your sessions',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.namaMediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Session Feedback',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View ratings and reviews from your attendees',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.namaMediumGray,
                  ),
                ),
                const SizedBox(height: 24),

                // Overall Rating Card (Placeholder)
                Card(
                  elevation: 2,
                  color: AppColors.namaLightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 48,
                          color: AppColors.namaGoldenYellow,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Average Rating',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.namaDarkGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'N/A', // TODO: Calculate from feedback
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.namaNavyBlue,
                                ),
                              ),
                              Text(
                                'Based on ${mySessions.length} sessions',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.namaMediumGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Session List
                Text(
                  'Session Reviews',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 12),

                // Placeholder message
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.feedback_outlined,
                          size: 56,
                          color: AppColors.namaNavyBlue.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Feedback System Coming Soon',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.namaNavyBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Attendees will be able to rate and review your sessions. Feedback will be displayed here.',
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

                // TODO: Implement actual feedback display
                // - List of sessions with ratings
                // - Individual feedback/comments
                // - Filter by session or rating
                // - Export feedback reports
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Text('Error loading feedback: $err'),
        ),
      ),
    );
  }
}
