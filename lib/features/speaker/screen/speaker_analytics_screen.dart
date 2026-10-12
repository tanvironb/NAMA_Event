import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final eventAsync = ref.watch(activeEventFutureProvider);
    final allSessionsAsync = eventAsync.when<AsyncValue<List<_AnalyticsSession>>>(
      data: (event) => event == null || userId == null
          ? const AsyncData<List<_AnalyticsSession>>([])
          : ref.watch(_analyticsProvider((event.id, userId))),
      loading: () => const AsyncLoading<List<_AnalyticsSession>>(),
      error: (error, stack) => AsyncError<List<_AnalyticsSession>>(error, stack),
    );
    // Refresh upcoming/completed counts even when Firestore has no new writes.
    ref.watch(_analyticsClockProvider);
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
                      .where((s) => s.assignedIds.contains(userId))
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
                  final ratings = mySessions.expand((s) => s.ratings).toList();
                  final avgRating = ratings.isEmpty ? '0.0'
                      : (ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(1);
                  final avgEngagementRate = totalSessions > 0
                      ? (mySessions.fold<double>(
                                  0, (sum, s) => sum + s.engagementRate) /
                              totalSessions)
                          .toStringAsFixed(1)
                      : '0.0';
                  final feedbackResponseRate = totalAttendees > 0
                      ? ((mySessions.fold<int>(0, (sum, s) => sum + s.feedbackRespondents.intersection(s.checkedInAttendees).length) / totalAttendees) * 100)
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
// Read-only, scoped to this page: no admin documents or providers are changed.
final _analyticsProvider = StreamProvider.autoDispose
    .family<List<_AnalyticsSession>, (String, String)>((ref, key) {
  return _watchAnalytics(key.$1, key.$2);
});

Stream<List<_AnalyticsSession>> _watchAnalytics(String eventId, String uid) {
  final db = FirebaseFirestore.instance;
  late StreamController<List<_AnalyticsSession>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sessionsSub;
  final children = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  var generation = 0;
  var stopped = false;
  var sessions = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final checkins = <String, QuerySnapshot<Map<String, dynamic>>>{};
  final chats = <String, QuerySnapshot<Map<String, dynamic>>>{};
  final feedback = <String, QuerySnapshot<Map<String, dynamic>>>{};

  void emit() {
    if (stopped || controller.isClosed) return;
    if (sessions.any((s) => !checkins.containsKey(s.id) || !chats.containsKey(s.id) || !feedback.containsKey(s.id))) {
      return;
    }
    controller.add(sessions.map((s) => _AnalyticsSession(
      s.data(), checkins[s.id]!.docs, chats[s.id]!.docs, feedback[s.id]!.docs,
    )).toList());
  }

  controller = StreamController<List<_AnalyticsSession>>(
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
        chats.clear();
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
          children.add(base.collection('chat').snapshots().listen((records) {
            if (stopped || token != generation) return;
            chats[session.id] = records;
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

class _AnalyticsSession {
  final Map<String, dynamic> data;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> checkins;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> messages;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> feedback;
  _AnalyticsSession(this.data, this.checkins, this.messages, this.feedback);

  int get totalMessages => messages.where((m) =>
      m.data()['deletedForEveryone'] != true).length;
  int get deletedMessagesCount {
    final recorded = data['deletedMessagesCount'];
    final tombstones = messages.where((m) => m.data()['deletedForEveryone'] == true).length;
    final count = recorded is num ? recorded.toInt() : 0;
    return count > tombstones ? count : tombstones;
  }
  // Historical actions require the stored counter; currently muted users are
  // not a count of past mute actions.
  int get totalMuteActions => data['totalMuteActions'] is num
      ? (data['totalMuteActions'] as num).toInt() : 0;
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

  Set<String> get uniqueParticipants => messages.map((document) =>
    (document.data()['senderId'] ?? '').toString().trim()
  ).where((id) => id.isNotEmpty).toSet();

  double get engagementRate {
    final attendees = checkedInAttendees;
    if (attendees.isEmpty) return 0;
    final engaged = uniqueParticipants.intersection(attendees).length;
    return engaged * 100 / attendees.length;
  }
}

final _analyticsClockProvider = StreamProvider.autoDispose<int>((ref) =>
    Stream<int>.periodic(const Duration(minutes: 1), (tick) => tick));
