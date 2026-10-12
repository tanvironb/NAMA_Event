import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
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
    final eventAsync = ref.watch(activeEventFutureProvider);
    final allSessionsAsync = eventAsync.when<AsyncValue<List<_FeedbackSession>>>(
      data: (event) => event == null || userId == null
          ? const AsyncData<List<_FeedbackSession>>([])
          : ref.watch(_feedbackSessionsProvider((event.id, userId))),
      loading: () => const AsyncLoading<List<_FeedbackSession>>(),
      error: (error, stack) => AsyncError<List<_FeedbackSession>>(error, stack),
    );
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
                            s.assignedIds.contains(userId),
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
                              'No Assigned Sessions',
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
                              'Sessions assigned to you as speaker or moderator will appear here.',
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
                  final ratings = mySessions.expand((s) => s.ratings).toList();
                  final avgRating = ratings.isEmpty ? 0.0
                      : ratings.reduce((a, b) => a + b) / ratings.length;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ratings & Reviews',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
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
                                      ratings.isNotEmpty
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
                                  ? ((session.feedbackRespondents.intersection(session.checkedInAttendees).length /
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
                                      session: session.model,
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
// Read-only, scoped to this page: no admin documents or providers are changed.
final _feedbackSessionsProvider = StreamProvider.autoDispose
    .family<List<_FeedbackSession>, (String, String)>((ref, key) {
  return _watchFeedbackSessions(key.$1, key.$2);
});

Stream<List<_FeedbackSession>> _watchFeedbackSessions(String eventId, String uid) {
  final db = FirebaseFirestore.instance;
  late StreamController<List<_FeedbackSession>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sessionsSub;
  final children = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  var generation = 0;
  var stopped = false;
  var sessions = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final checkins = <String, QuerySnapshot<Map<String, dynamic>>>{};
  final feedback = <String, QuerySnapshot<Map<String, dynamic>>>{};

  void emit() {
    if (stopped || controller.isClosed) return;
    if (sessions.any((s) => !checkins.containsKey(s.id) || !feedback.containsKey(s.id))) {
      return;
    }
    controller.add(sessions.map((s) => _FeedbackSession(
      s, checkins[s.id]!.docs, feedback[s.id]!.docs,
    )).toList());
  }

  controller = StreamController<List<_FeedbackSession>>(
    onListen: () {
      sessionsSub = db.collection('sessions')
          .where('eventId', isEqualTo: eventId).snapshots().listen((snapshot) async {
        final token = ++generation;
        final previous = List.of(children);
        children.clear();
        for (final sub in previous) { await sub.cancel(); }
        if (stopped || token != generation) return;
        sessions = snapshot.docs.where((document) {
          final data = document.data();
          return _ids(data['speakerIds']).contains(uid) ||
              _ids(data['moderatorIds']).contains(uid);
        }).toList();
        checkins.clear();
        feedback.clear();
        if (sessions.isEmpty) { emit(); return; }
        for (final session in sessions) {
          final base = db.collection('sessions').doc(session.id);
          children.add(base.collection('checkins').snapshots().listen((records) {
            if (stopped || token != generation) return;
            checkins[session.id] = records;
            emit();
          }, onError: (Object error, StackTrace stack) {
            if (!stopped && token == generation) controller.addError(error, stack);
          }));
          children.add(base.collection('feedback').snapshots().listen((records) {
            if (stopped || token != generation) return;
            feedback[session.id] = records;
            emit();
          }, onError: (Object error, StackTrace stack) {
            if (!stopped && token == generation) controller.addError(error, stack);
          }));

        }
      }, onError: (Object error, StackTrace stack) {
        if (!stopped) controller.addError(error, stack);
      });
    },
    onCancel: () async {
      stopped = true;
      generation++;
      await sessionsSub?.cancel();
      for (final sub in children) { await sub.cancel(); }
      children.clear();
    },
  );
  return controller.stream;
}

Set<String> _ids(dynamic value) => value is List
    ? value.whereType<String>().where((id) => id.trim().isNotEmpty).toSet()
    : <String>{};

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class _FeedbackSession {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  Map<String, dynamic> get data => document.data();
  Session get model => Session.fromFirestore(document);
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> checkins;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> feedback;
  _FeedbackSession(this.document, this.checkins, this.feedback);

  int get totalFeedbacks => feedback.length;
  List<double> get ratings => feedback.map((document) {
    final value = document.data()['rating'];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }).whereType<double>().where((v) => v >= 1 && v <= 5).toList();
  Set<String> get feedbackRespondents => feedback.map((document) {
    final record = document.data();
    return (record['userId'] ?? record['attendeeId'] ?? record['uid'] ?? document.id)
        .toString().trim();
  }).where((id) => id.isNotEmpty).toSet();

  Set<String> get assignedIds => {
    ..._ids(data['speakerIds']), ..._ids(data['moderatorIds']),
  };
  String get title => (data['title'] ?? 'Session').toString();
  String get location => (data['location'] ?? '—').toString();
  DateTime get startTime => _date(data['startTime']) ?? DateTime(1970);
  DateTime get endTime => _date(data['endTime']) ?? startTime;

  // Records are authoritative, including removals. Do not merge stale session arrays.
  Set<String> get checkedInAttendees => checkins.map((document) {
    final record = document.data();
    return (record['userId'] ?? record['attendeeId'] ?? record['uid'] ?? document.id)
        .toString().trim();
  }).where((id) => id.isNotEmpty).toSet();

  double get averageRating => ratings.isEmpty ? 0
      : ratings.reduce((a, b) => a + b) / ratings.length;
}
