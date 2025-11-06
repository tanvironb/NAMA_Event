import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/models/session_feedback_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

/// Session Feedback Detail Screen
/// Shows all individual feedback reviews for a specific session
class SessionFeedbackDetailScreen extends ConsumerStatefulWidget {
  final Session session;

  const SessionFeedbackDetailScreen({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<SessionFeedbackDetailScreen> createState() =>
      _SessionFeedbackDetailScreenState();
}

class _SessionFeedbackDetailScreenState
    extends ConsumerState<SessionFeedbackDetailScreen> {
  int? _selectedRatingFilter; // null means show all

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Reviews'),
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: AppColors.namaWhite,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.session.id)
            .collection('feedback')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.errorRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading reviews',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.namaDarkGray,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.namaMediumGray,
                        ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                      'No Reviews Yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.namaDarkGray,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reviews from attendees will appear here',
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

          final feedbackDocs = snapshot.data!.docs;
          final feedbacks = feedbackDocs
              .map((doc) => SessionFeedback.fromFirestore(doc))
              .toList();

          // Calculate rating distribution
          final ratingDistribution = <int, int>{};
          for (final feedback in feedbacks) {
            ratingDistribution[feedback.rating] =
                (ratingDistribution[feedback.rating] ?? 0) + 1;
          }

          // Filter feedbacks based on selected rating
          final filteredFeedbacks = _selectedRatingFilter == null
              ? feedbacks
              : feedbacks
                  .where((f) => f.rating == _selectedRatingFilter)
                  .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Header
                Card(
                  elevation: 2,
                  color: AppColors.namaLightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.namaNavyBlue,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 24,
                              color: AppColors.namaGoldenYellow,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.session.averageRating.toStringAsFixed(1),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.namaNavyBlue,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${widget.session.totalFeedbacks} ${widget.session.totalFeedbacks == 1 ? 'review' : 'reviews'})',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: AppColors.namaMediumGray,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Rating Filter Chips
                if (ratingDistribution.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // "All" filter chip
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text('All (${feedbacks.length})'),
                            selected: _selectedRatingFilter == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedRatingFilter = null;
                              });
                            },
                            selectedColor: AppColors.namaNavyBlue,
                            checkmarkColor: AppColors.namaWhite,
                            labelStyle: TextStyle(
                              color: _selectedRatingFilter == null
                                  ? AppColors.namaWhite
                                  : AppColors.namaNavyBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Rating filter chips (5 to 1 stars)
                        ...List.generate(5, (index) {
                          final rating = 5 - index; // 5, 4, 3, 2, 1
                          final count = ratingDistribution[rating] ?? 0;

                          // Only show chips for ratings that exist
                          if (count == 0) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: _selectedRatingFilter == rating
                                        ? AppColors.namaWhite
                                        : AppColors.namaGoldenYellow,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$rating'),
                                  const SizedBox(width: 4),
                                  Text(
                                    '($count)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedRatingFilter == rating
                                          ? AppColors.namaWhite.withOpacity(0.8)
                                          : AppColors.namaMediumGray,
                                    ),
                                  ),
                                ],
                              ),
                              selected: _selectedRatingFilter == rating,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedRatingFilter = selected ? rating : null;
                                });
                              },
                              selectedColor: AppColors.namaNavyBlue,
                              checkmarkColor: AppColors.namaWhite,
                              labelStyle: TextStyle(
                                color: _selectedRatingFilter == rating
                                    ? AppColors.namaWhite
                                    : AppColors.namaNavyBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Reviews Header
                Text(
                  'Reviews',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.namaNavyBlue,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${filteredFeedbacks.length} ${filteredFeedbacks.length == 1 ? 'review' : 'reviews'}${_selectedRatingFilter != null ? ' with $_selectedRatingFilter ${_selectedRatingFilter == 1 ? 'star' : 'stars'}' : ' from attendees'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.namaMediumGray,
                      ),
                ),
                const SizedBox(height: 16),

                // Individual Reviews
                ...filteredFeedbacks.map((feedback) {
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
                          // Header row with user and rating
                          Row(
                            children: [
                              // User avatar
                              CircleAvatar(
                                backgroundColor: feedback.isAnonymous
                                    ? AppColors.namaMediumGray
                                    : AppColors.namaLightBlue,
                                radius: 20,
                                child: Icon(
                                  feedback.isAnonymous
                                      ? Icons.person_off
                                      : Icons.person,
                                  color: feedback.isAnonymous
                                      ? AppColors.namaWhite
                                      : AppColors.namaNavyBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      feedback.isAnonymous
                                          ? 'Anonymous'
                                          : feedback.userName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.namaNavyBlue,
                                          ),
                                    ),
                                    Text(
                                      DateFormat('MMM dd, yyyy \'at\' hh:mm a')
                                          .format(feedback.timestamp),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.namaMediumGray,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              // Rating stars
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    index < feedback.rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: AppColors.namaGoldenYellow,
                                    size: 20,
                                  );
                                }),
                              ),
                            ],
                          ),

                          // Comment if provided
                          if (feedback.comment.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                feedback.comment,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.namaDarkGray,
                                    ),
                              ),
                            ),
                          ],
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
      ),
    );
  }
}
