import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_detail_screen.dart';

/// Session Feedback Screen
/// Shows ratings and feedback from attendees for speaker's sessions.
class SessionFeedbackScreen extends ConsumerWidget {
  const SessionFeedbackScreen({super.key});

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
                    'Session Feedback',
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
                      .where(
                        (s) =>
                            s.speakerIds.contains(userId) &&
                            s.endTime.isBefore(DateTime.now()),
                      )
                      .toList();

                  if (mySessions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 50,
                              color:
                                  AppColors.namaMediumGray.withOpacity(0.45),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No Completed Sessions',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.namaDarkGray,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Feedback will appear here after you complete your sessions',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.namaMediumGray,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final totalFeedbacks = mySessions.fold<int>(
                    0,
                    (sum, s) => sum + s.totalFeedbacks,
                  );

                  final sessionsWithFeedback =
                      mySessions.where((s) => s.totalFeedbacks > 0).toList();

                  final avgRating = sessionsWithFeedback.isEmpty
                      ? 0.0
                      : sessionsWithFeedback.fold<double>(
                            0,
                            (sum, s) => sum + s.averageRating,
                          ) /
                          sessionsWithFeedback.length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Feedback',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.namaNavyBlue,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'View ratings and reviews from your attendees',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.namaMediumGray,
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                        ),

                        const SizedBox(height: 22),

                        // Overall Rating Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                          decoration: BoxDecoration(
                            color: AppColors.namaLightBlue,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.035),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.namaGoldenYellow
                                      .withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.star,
                                  size: 24,
                                  color: AppColors.namaGoldenYellow,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Average Rating',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.namaDarkGray,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      totalFeedbacks > 0
                                          ? avgRating.toStringAsFixed(1)
                                          : 'No ratings yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.namaNavyBlue,
                                            fontSize: totalFeedbacks > 0
                                                ? 22
                                                : 18,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Based on $totalFeedbacks ${totalFeedbacks == 1 ? 'feedback' : 'feedbacks'} from ${mySessions.length} ${mySessions.length == 1 ? 'session' : 'sessions'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.namaMediumGray,
                                            fontSize: 11.5,
                                            height: 1.25,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        Text(
                          'Session Reviews',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.namaNavyBlue,
                                  ),
                        ),

                        const SizedBox(height: 12),

                        ...mySessions.map((session) {
                          final responseRate =
                              session.checkedInAttendees.isNotEmpty &&
                                      session.totalFeedbacks > 0
                                  ? ((session.totalFeedbacks /
                                              session.checkedInAttendees.length) *
                                          100)
                                      .toStringAsFixed(0)
                                  : null;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SessionFeedbackDetailScreen(
                                      session: session,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 13, 14, 13),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            session.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppColors.namaNavyBlue,
                                                  height: 1.2,
                                                ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: AppColors.namaMediumGray,
                                          size: 22,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    Row(
                                      children: [
                                        if (session.totalFeedbacks > 0) ...[
                                          Icon(
                                            Icons.star,
                                            size: 17,
                                            color:
                                                AppColors.namaGoldenYellow,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            session.averageRating
                                                .toStringAsFixed(1),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppColors.namaNavyBlue,
                                                ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '(${session.totalFeedbacks} ${session.totalFeedbacks == 1 ? 'review' : 'reviews'})',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors
                                                      .namaMediumGray,
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ] else ...[
                                          Icon(
                                            Icons.feedback_outlined,
                                            size: 17,
                                            color:
                                                AppColors.namaMediumGray,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'No feedback yet',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors
                                                      .namaMediumGray,
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    const SizedBox(height: 9),

                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 15,
                                          color: AppColors.namaMediumGray,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${session.checkedInAttendees.length} attendees',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors
                                                    .namaMediumGray,
                                                fontSize: 11.5,
                                              ),
                                        ),
                                        if (responseRate != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '• $responseRate% response rate',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors
                                                      .namaMediumGray,
                                                  fontSize: 11.5,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    if (session.totalFeedbacks > 0) ...[
                                      const SizedBox(height: 9),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.touch_app,
                                            size: 13,
                                            color: AppColors.namaNavyBlue
                                                .withOpacity(0.6),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Tap to view reviews',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors
                                                      .namaNavyBlue
                                                      .withOpacity(0.6),
                                                  fontSize: 11,
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
                        }),

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
                      'Error loading feedback: $err',
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