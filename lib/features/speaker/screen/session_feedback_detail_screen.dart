import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

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
  int? _selectedRatingFilter;

  Stream<QuerySnapshot<Map<String, dynamic>>> _feedbackStream() {
    return FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.session.id)
        .collection('feedback')
        .snapshots();
  }

  List<_ReviewItem> _parseReviews(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final reviews = snapshot.docs.map((doc) {
      final data = doc.data();

      final timestampValue = data['timestamp'];
      DateTime timestamp = DateTime.now();

      if (timestampValue is Timestamp) {
        timestamp = timestampValue.toDate();
      }

      return _ReviewItem(
        id: doc.id,
        sessionId: (data['sessionId'] ?? '').toString(),
        userId: (data['userId'] ?? '').toString(),
        userName: (data['userName'] ?? 'Anonymous').toString(),
        isAnonymous: data['isAnonymous'] == true,
        rating: (data['rating'] as num?)?.toInt() ?? 0,
        comment: (data['comment'] ?? '').toString(),
        userRole: (data['userRole'] ?? '').toString(),
        timestamp: timestamp,
      );
    }).where((review) {
      return review.rating > 0;
    }).toList();

    reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return reviews;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
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
                    'Session Reviews',
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
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _feedbackStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const LoadingIndicator();
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(
                      error: snapshot.error.toString(),
                    );
                  }

                  final reviews = snapshot.hasData
                      ? _parseReviews(snapshot.data!)
                      : <_ReviewItem>[];

                  if (reviews.isEmpty) {
                    return _EmptyState(
                      sessionTitle: widget.session.title,
                      expectedCount: widget.session.totalFeedbacks,
                    );
                  }

                  final ratingDistribution = <int, int>{};

                  for (final review in reviews) {
                    ratingDistribution[review.rating] =
                        (ratingDistribution[review.rating] ?? 0) + 1;
                  }

                  final filteredReviews = _selectedRatingFilter == null
                      ? reviews
                      : reviews
                          .where(
                            (review) =>
                                review.rating == _selectedRatingFilter,
                          )
                          .toList();

                  final totalRating = reviews.fold<int>(
                    0,
                    (sum, review) => sum + review.rating,
                  );

                  final averageRating =
                      reviews.isEmpty ? 0.0 : totalRating / reviews.length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SessionSummaryCard(
                          title: widget.session.title,
                          averageRating: averageRating,
                          reviewCount: reviews.length,
                        ),

                        const SizedBox(height: 16),

                        if (ratingDistribution.isNotEmpty) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text('All (${reviews.length})'),
                                    selected: _selectedRatingFilter == null,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedRatingFilter = null;
                                      });
                                    },
                                    selectedColor: AppColors.namaNavyBlue,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: _selectedRatingFilter == null
                                          ? Colors.white
                                          : AppColors.namaNavyBlue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ...List.generate(5, (index) {
                                  final rating = 5 - index;
                                  final count = ratingDistribution[rating] ?? 0;

                                  if (count == 0) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 15,
                                            color:
                                                _selectedRatingFilter == rating
                                                    ? Colors.white
                                                    : AppColors
                                                        .namaGoldenYellow,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('$rating ($count)'),
                                        ],
                                      ),
                                      selected: _selectedRatingFilter == rating,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedRatingFilter =
                                              selected ? rating : null;
                                        });
                                      },
                                      selectedColor: AppColors.namaNavyBlue,
                                      checkmarkColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color:
                                            _selectedRatingFilter == rating
                                                ? Colors.white
                                                : AppColors.namaNavyBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        Text(
                          'Reviews',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.namaNavyBlue,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filteredReviews.length} ${filteredReviews.length == 1 ? 'review' : 'reviews'}${_selectedRatingFilter != null ? ' with $_selectedRatingFilter ${_selectedRatingFilter == 1 ? 'star' : 'stars'}' : ' from attendees'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.namaMediumGray,
                                    fontSize: 12,
                                  ),
                        ),

                        const SizedBox(height: 12),

                        ...filteredReviews.map((review) {
                          return _ReviewCard(review: review);
                        }),

                        const SizedBox(height: 10),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  final String title;
  final double averageRating;
  final int reviewCount;

  const _SessionSummaryCard({
    required this.title,
    required this.averageRating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.namaNavyBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.star,
                size: 20,
                color: AppColors.namaGoldenYellow,
              ),
              const SizedBox(width: 6),
              Text(
                averageRating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.namaNavyBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '($reviewCount ${reviewCount == 1 ? 'review' : 'reviews'})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.namaMediumGray,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _ReviewItem review;

  const _ReviewCard({
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = review.isAnonymous || review.userName.trim().isEmpty
        ? 'Anonymous'
        : review.userName;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: review.isAnonymous
                    ? AppColors.namaMediumGray.withOpacity(0.35)
                    : AppColors.namaLightBlue,
                child: Icon(
                  review.isAnonymous ? Icons.person_off : Icons.person,
                  color: review.isAnonymous
                      ? AppColors.namaMediumGray
                      : AppColors.namaNavyBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.namaNavyBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    color: AppColors.namaGoldenYellow,
                    size: 17,
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            DateFormat('MMM dd, yyyy • hh:mm a').format(review.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.namaMediumGray,
                  fontSize: 11,
                ),
          ),

          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                review.comment,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.namaDarkGray,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String sessionTitle;
  final int expectedCount;

  const _EmptyState({
    required this.sessionTitle,
    required this.expectedCount,
  });

  @override
  Widget build(BuildContext context) {
    final message = expectedCount > 0
        ? 'This session summary shows $expectedCount feedback, but no feedback document exists under this session.'
        : 'Reviews from attendees will appear here';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 50,
              color: AppColors.namaMediumGray.withOpacity(0.45),
            ),
            const SizedBox(height: 14),
            Text(
              'No Reviews Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.namaDarkGray,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.namaMediumGray,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              sessionTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.namaNavyBlue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 50,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 14),
            Text(
              'Error loading reviews',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.namaDarkGray,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.namaMediumGray,
                    fontSize: 12,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem {
  final String id;
  final String sessionId;
  final String userId;
  final String userName;
  final bool isAnonymous;
  final int rating;
  final String comment;
  final String userRole;
  final DateTime timestamp;

  const _ReviewItem({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.userName,
    required this.isAnonymous,
    required this.rating,
    required this.comment,
    required this.userRole,
    required this.timestamp,
  });
}