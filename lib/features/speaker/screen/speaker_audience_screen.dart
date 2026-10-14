import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class SpeakerAudienceScreen extends ConsumerWidget {
  const SpeakerAudienceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final eventAsync = ref.watch(activeEventFutureProvider);
    final allSessionsAsync = eventAsync.when<
      AsyncValue<List<_AudienceSession>>
    >(
      data:
          (event) =>
              event == null || userId == null
                  ? const AsyncData<List<_AudienceSession>>([])
                  : ref.watch(_audienceProvider((event.id, userId))),
      loading: () => const AsyncLoading<List<_AudienceSession>>(),
      error: (error, stack) => AsyncError<List<_AudienceSession>>(error, stack),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            // Static header
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
                    'My Audience',
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
                  final mySessions =
                      allSessions
                          .where((s) => s.assignedIds.contains(userId))
                          .toList();
                  final uniqueAttendees =
                      mySessions
                          .expand((s) => s.checkedInAttendees)
                          .toSet()
                          .length;
                  final totalCheckIns = mySessions.fold<int>(
                    0,
                    (sum, session) => sum + session.checkedInAttendees.length,
                  );
                  final chatParticipants =
                      mySessions
                          .expand((s) => s.uniqueParticipants)
                          .toSet()
                          .length;
                  final avgEngagementRate =
                      mySessions.isNotEmpty
                          ? (mySessions.fold<double>(
                                    0,
                                    (sum, s) => sum + s.engagementRate,
                                  ) /
                                  mySessions.length)
                              .toStringAsFixed(0)
                          : '0';
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audience Insights',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.namaNavyBlue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connect with attendees interested in your sessions',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: AppColors.namaMediumGray,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 22),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.08,
                          children: [
                            _AudienceStatCard(
                              icon: Icons.person_add_alt_1_outlined,
                              value: '$uniqueAttendees',
                              label: 'Unique Attendees',
                              iconColor: AppColors.namaNavyBlue,
                              backgroundTint: AppColors.namaNavyBlue
                                  .withOpacity(0.08),
                            ),
                            _AudienceStatCard(
                              icon: Icons.qr_code_scanner_outlined,
                              value: '$totalCheckIns',
                              label: 'Total Check-ins',
                              iconColor: AppColors.namaGoldenYellow,
                              backgroundTint: AppColors.namaGoldenYellow
                                  .withOpacity(0.16),
                            ),
                            _AudienceStatCard(
                              icon: Icons.chat_bubble_outline,
                              value: '$chatParticipants',
                              label: 'Chat Participants',
                              iconColor: AppColors.infoBlue,
                              backgroundTint: AppColors.infoBlue.withOpacity(
                                0.08,
                              ),
                            ),
                            _AudienceStatCard(
                              icon: Icons.percent_outlined,
                              value: '$avgEngagementRate%',
                              label: 'Engagement Rate',
                              iconColor: AppColors.successGreen,
                              backgroundTint: AppColors.successGreen
                                  .withOpacity(0.08),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Session Breakdown',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.namaNavyBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (mySessions.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
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
                            child: Text(
                              'No sessions found for this speaker.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: AppColors.namaMediumGray,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            itemCount: mySessions.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final session = mySessions[index];
                              final attendeeCount =
                                  session.checkedInAttendees.length;
                              final participantsCount =
                                  session.uniqueParticipants.length;
                              return _SessionAudienceCard(
                                title: session.title,
                                location: session.location,
                                timeText:
                                    '${DateFormat.jm().format(session.startTime)} - ${DateFormat.jm().format(session.endTime)}',
                                attendees: attendeeCount,
                                participants: participantsCount,
                                engagementRate:
                                    '${session.engagementRate.toStringAsFixed(0)}%',
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const LoadingIndicator(),
                error:
                    (err, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error loading audience data: $err',
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

class _AudienceStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color backgroundTint;
  const _AudienceStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.backgroundTint,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: backgroundTint,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: iconColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: AppColors.namaDarkGray,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionAudienceCard extends StatelessWidget {
  final String title;
  final String location;
  final String timeText;
  final int attendees;
  final int participants;
  final String engagementRate;
  const _SessionAudienceCard({
    required this.title,
    required this.location,
    required this.timeText,
    required this.attendees,
    required this.participants,
    required this.engagementRate,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
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
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.namaNavyBlue,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 15,
                color: AppColors.namaMediumGray,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  timeText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: AppColors.namaMediumGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.namaMediumGray,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: AppColors.namaMediumGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Attendees',
                  value: '$attendees',
                  color: AppColors.namaNavyBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  label: 'Chat',
                  value: '$participants',
                  color: AppColors.infoBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  label: 'Rate',
                  value: engagementRate,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              color: AppColors.namaDarkGray,
            ),
          ),
        ],
      ),
    );
  }
}

// Read-only, scoped to this page: no admin documents or providers are changed.
final _audienceProvider = StreamProvider.autoDispose
    .family<List<_AudienceSession>, (String, String)>((ref, key) {
      return _watchAudience(key.$1, key.$2);
    });

Stream<List<_AudienceSession>> _watchAudience(String eventId, String uid) {
  final db = FirebaseFirestore.instance;
  late StreamController<List<_AudienceSession>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sessionsSub;
  final children = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  var generation = 0;
  var stopped = false;
  var sessions = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final checkins = <String, QuerySnapshot<Map<String, dynamic>>>{};
  final chats = <String, QuerySnapshot<Map<String, dynamic>>>{};

  void emit() {
    if (stopped || controller.isClosed) return;
    if (sessions.any(
      (s) => !checkins.containsKey(s.id) || !chats.containsKey(s.id),
    )) {
      return;
    }
    controller.add(
      sessions
          .map(
            (s) => _AudienceSession(
              s.data(),
              checkins[s.id]!.docs,
              chats[s.id]!.docs,
            ),
          )
          .toList(),
    );
  }

  controller = StreamController<List<_AudienceSession>>(
    onListen: () {
      sessionsSub = db
          .collection('sessions')
          .where('eventId', isEqualTo: eventId)
          .snapshots()
          .listen(
            (snapshot) async {
              final token = ++generation;
              final previous = List.of(children);
              children.clear();
              for (final sub in previous) {
                await sub.cancel();
              }
              if (stopped || token != generation) return;
              sessions =
                  snapshot.docs.where((document) {
                    final data = document.data();
                    return _ids(data['speakerIds']).contains(uid) ||
                        _ids(data['moderatorIds']).contains(uid);
                  }).toList();
              checkins.clear();
              chats.clear();
              if (sessions.isEmpty) {
                emit();
                return;
              }
              for (final session in sessions) {
                final base = db.collection('sessions').doc(session.id);
                children.add(
                  base
                      .collection('checkins')
                      .snapshots()
                      .listen(
                        (records) {
                          if (stopped || token != generation) return;
                          checkins[session.id] = records;
                          emit();
                        },
                        onError: (Object error, StackTrace stack) {
                          if (!stopped && token == generation)
                            controller.addError(error, stack);
                        },
                      ),
                );
                children.add(
                  base
                      .collection('chat')
                      .snapshots()
                      .listen(
                        (records) {
                          if (stopped || token != generation) return;
                          chats[session.id] = records;
                          emit();
                        },
                        onError: (Object error, StackTrace stack) {
                          if (!stopped && token == generation)
                            controller.addError(error, stack);
                        },
                      ),
                );
              }
            },
            onError: (Object error, StackTrace stack) {
              if (!stopped) controller.addError(error, stack);
            },
          );
    },
    onCancel: () async {
      stopped = true;
      generation++;
      await sessionsSub?.cancel();
      for (final sub in children) {
        await sub.cancel();
      }
      children.clear();
    },
  );
  return controller.stream;
}

Set<String> _ids(dynamic value) =>
    value is List
        ? value.whereType<String>().where((id) => id.trim().isNotEmpty).toSet()
        : <String>{};

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class _AudienceSession {
  final Map<String, dynamic> data;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> checkins;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> messages;
  _AudienceSession(this.data, this.checkins, this.messages);

  Set<String> get assignedIds => {
    ..._ids(data['speakerIds']),
    ..._ids(data['moderatorIds']),
  };
  String get title => (data['title'] ?? 'Session').toString();
  String get location => (data['location'] ?? '—').toString();
  DateTime get startTime => _date(data['startTime']) ?? DateTime(1970);
  DateTime get endTime => _date(data['endTime']) ?? startTime;

  // Records are authoritative, including removals. Do not merge stale session arrays.
  Set<String> get checkedInAttendees =>
      checkins
          .map((document) {
            final record = document.data();
            return (record['userId'] ??
                    record['attendeeId'] ??
                    record['uid'] ??
                    document.id)
                .toString()
                .trim();
          })
          .where((id) => id.isNotEmpty)
          .toSet();

  Set<String> get uniqueParticipants =>
      messages
          .where((document) => document.data()['deletedForEveryone'] != true)
          .map(
            (document) => (document.data()['senderId'] ?? '').toString().trim(),
          )
          .where((id) => id.isNotEmpty)
          .toSet();

  double get engagementRate {
    final attendees = checkedInAttendees;
    if (attendees.isEmpty) return 0;
    final engaged = uniqueParticipants.intersection(attendees).length;
    return engaged * 100 / attendees.length;
  }
}
