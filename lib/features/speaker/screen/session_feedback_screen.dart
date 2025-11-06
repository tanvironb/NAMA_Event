import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_detail_screen.dart';

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

          // Calculate overall stats
          final totalFeedbacks = mySessions.fold<int>(
            0,
            (sum, s) => sum + s.totalFeedbacks,
          );
          final avgRating = mySessions.where((s) => s.totalFeedbacks > 0).isEmpty
            ? 0.0
            : (mySessions
                .where((s) => s.totalFeedbacks > 0)
                .fold<double>(0, (sum, s) => sum + s.averageRating) /
                mySessions.where((s) => s.totalFeedbacks > 0).length);

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

                // Overall Rating Card
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
                                totalFeedbacks > 0 
                                  ? avgRating.toStringAsFixed(1)
                                  : 'No ratings yet',
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.namaNavyBlue,
                                ),
                              ),
                              Text(
                                'Based on $totalFeedbacks ${totalFeedbacks == 1 ? 'feedback' : 'feedbacks'} from ${mySessions.length} ${mySessions.length == 1 ? 'session' : 'sessions'}',
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

                // List sessions with feedback
                ...mySessions.map((session) {
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Navigate to detail screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SessionFeedbackDetailScreen(
                              session: session,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Session title with chevron
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    session.title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.namaNavyBlue,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: AppColors.namaMediumGray,
                                  size: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Feedback stats
                            Row(
                              children: [
                                if (session.totalFeedbacks > 0) ...[
                                  Icon(
                                    Icons.star,
                                    size: 20,
                                    color: AppColors.namaGoldenYellow,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    session.averageRating.toStringAsFixed(1),
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.namaNavyBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${session.totalFeedbacks} ${session.totalFeedbacks == 1 ? 'review' : 'reviews'})',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.namaMediumGray,
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.feedback_outlined,
                                    size: 20,
                                    color: AppColors.namaMediumGray,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'No feedback yet',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.namaMediumGray,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Attendee stats
                            Row(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 16,
                                  color: AppColors.namaMediumGray,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${session.checkedInAttendees.length} attendees',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.namaMediumGray,
                                  ),
                                ),
                                if (session.checkedInAttendees.isNotEmpty && session.totalFeedbacks > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${((session.totalFeedbacks / session.checkedInAttendees.length) * 100).toStringAsFixed(0)}% response rate',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.namaMediumGray,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            
                            // Hint text to tap
                            if (session.totalFeedbacks > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 14,
                                    color: AppColors.namaNavyBlue.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tap to view reviews',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.namaNavyBlue.withOpacity(0.6),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
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
          child: Text('Error loading feedback: $err'),
        ),
      ),
    );
  }
}
