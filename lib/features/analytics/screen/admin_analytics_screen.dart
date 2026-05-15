// lib/features/analytics/screen/admin_analytics_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({
    super.key,
    required this.eventId,
  });

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: StreamBuilder<_AdminAnalyticsData>(
          stream: _AdminAnalyticsRepository().watchAdminAnalytics(eventId),
          initialData: _AdminAnalyticsData.empty(),
          builder: (context, snapshot) {
            final data = snapshot.data ?? _AdminAnalyticsData.empty();

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load analytics.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.namaDarkGray,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopHeader(
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Event Performance',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Monitor sessions, event users, engagement, and app usage',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.namaMediumGray,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('Event Overview'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Sessions',
                          value: _formatNumber(data.totalSessions),
                          icon: Icons.calendar_month_rounded,
                          color: AppColors.namaNavyBlue,
                          iconBackground: const Color(0xFFE9E7FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'Upcoming',
                          value: _formatNumber(data.upcomingSessions),
                          icon: Icons.access_time_rounded,
                          color: AppColors.namaGoldenYellow,
                          iconBackground: const Color(0xFFFFF3D8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Completed',
                          value: _formatNumber(data.completedSessions),
                          icon: Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          iconBackground: const Color(0xFFE7F6E9),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'Event Users',
                          value: _formatNumber(data.totalUsers),
                          icon: Icons.groups_rounded,
                          color: AppColors.namaGoldenYellow,
                          iconBackground: const Color(0xFFFFF3D8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('User Insights'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Active Users',
                          value: _formatNumber(data.activeUsers),
                          icon: Icons.person_rounded,
                          color: Colors.blue,
                          iconBackground: const Color(0xFFE5F0FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _UserRolesCard(data: data),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ChartCard(
                    title: 'Attendance Insights',
                    subtitle: 'Average attendance across all sessions',
                    child: SizedBox(
                      height: 210,
                      child: data.totalAttendance == 0 && data.totalNoShow == 0
                          ? const _EmptyChartText('No attendance data yet')
                          : _AttendancePieChart(
                              attended: data.totalAttendance,
                              noShow: data.totalNoShow,
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ChartCard(
                          title: 'Chat Activity',
                          subtitle:
                              '${_formatNumber(data.totalMessages)} messages',
                          child: SizedBox(
                            height: 145,
                            child: data.messagesByDay.isEmpty
                                ? const _EmptyChartText('No chat data yet')
                                : _ChatActivityBarChart(
                                    values: data.messagesByDay,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChartCard(
                          title: 'Engagement',
                          subtitle: '${data.engagementRate}% active',
                          child: SizedBox(
                            height: 145,
                            child: _EngagementGauge(
                              percentage: data.engagementRate,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ChartCard(
                    title: 'Messages Over Time',
                    subtitle: 'Chat activity throughout the day',
                    child: SizedBox(
                      height: 180,
                      child: data.messagesByHour.isEmpty
                          ? const _EmptyChartText('No hourly messages yet')
                          : _MessagesAreaChart(
                              values: data.messagesByHour,
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ChartCard(
                    title: 'Attendance Trend',
                    subtitle: 'Check-ins per session',
                    child: SizedBox(
                      height: 170,
                      child: data.attendanceTrend.isEmpty
                          ? const _EmptyChartText('No session check-ins yet')
                          : _AttendanceLineChart(
                              values: data.attendanceTrend,
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ChartCard(
                    title: 'Session Performance Metrics',
                    subtitle: 'Multi-dimensional analysis',
                    child: SizedBox(
                      height: 220,
                      child: _RadarPerformanceChart(data: data),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailedMetricsCard(data: data),
                  const SizedBox(height: 18),
                  const _SectionTitle('App Analytics'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'App Downloads',
                          value: _formatNumber(data.appDownloads),
                          icon: Icons.download_rounded,
                          color: AppColors.namaNavyBlue,
                          iconBackground: const Color(0xFFE9E7FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'Avg. Screen Time',
                          value: '${data.avgScreenTimeMinutes} min',
                          icon: Icons.timer_outlined,
                          color: AppColors.namaGoldenYellow,
                          iconBackground: const Color(0xFFFFF3D8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PeakActivityCard(data: data),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.namaNavyBlue,
              size: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Admin Analytics Dashboard',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminAnalyticsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<_AdminAnalyticsData> watchAdminAnalytics(String eventId) {
    final controller = StreamController<_AdminAnalyticsData>.broadcast();

    final subscriptions = <StreamSubscription>[];

    List<QueryDocumentSnapshot<Map<String, dynamic>>> usersDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> topLevelSessionsDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> eventSessionsDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messagesDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> checkInsDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> feedbackDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> installsDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> screenTimeDocs = [];

    void emit() {
      if (controller.isClosed) return;

      final mergedSessions =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      for (final doc in topLevelSessionsDocs) {
        mergedSessions[doc.reference.path] = doc;
      }

      for (final doc in eventSessionsDocs) {
        mergedSessions[doc.reference.path] = doc;
      }

      controller.add(
        _AdminAnalyticsData.fromDocs(
          eventId: eventId,
          usersDocs: usersDocs,
          sessionsDocs: mergedSessions.values.toList(),
          messagesDocs: messagesDocs,
          checkInsDocs: checkInsDocs,
          feedbackDocs: feedbackDocs,
          installsDocs: installsDocs,
          screenTimeDocs: screenTimeDocs,
        ),
      );
    }

    controller.add(_AdminAnalyticsData.empty());

    subscriptions.add(
      _firestore.collection('users').snapshots().listen(
        (snap) {
          usersDocs = snap.docs;
          emit();
        },
        onError: (e) {
          debugPrint('Admin Analytics users error: $e');
          usersDocs = [];
          emit();
        },
      ),
    );

    subscriptions.add(
      _firestore
          .collection('sessions')
          .where('eventId', isEqualTo: eventId)
          .snapshots()
          .listen(
        (snap) {
          topLevelSessionsDocs = snap.docs;
          emit();
        },
        onError: (e) {
          debugPrint('Admin Analytics top-level sessions error: $e');
          topLevelSessionsDocs = [];
          emit();
        },
      ),
    );

    subscriptions.add(
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('sessions')
          .snapshots()
          .listen(
        (snap) {
          eventSessionsDocs = snap.docs;
          emit();
        },
        onError: (e) {
          debugPrint('Admin Analytics event sessions error: $e');
          eventSessionsDocs = [];
          emit();
        },
      ),
    );

    subscriptions.add(
      _firestore
          .collectionGroup('messages')
          .where('eventId', isEqualTo: eventId)
          .snapshots()
          .listen(
        (snap) {
          messagesDocs = snap.docs;
          emit();
        },
        onError: (e) {
          debugPrint('Admin Analytics messages error: $e');
          messagesDocs = [];
          emit();
        },
      ),
    );

    subscriptions.add(
      _firestore
          .collectionGroup('checkIns')
          .where('eventId', isEqualTo: eventId)
          .snapshots()
          .listen(
        (snap) {
          checkInsDocs = snap.docs;
          emit();
        },
        onError: (e) {
          debugPrint('Admin Analytics checkIns error: $e');
          checkInsDocs = [];
          emit();
        },
      ),
    );

    subscriptions.add(
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('feedback')
          .snapshots()
          .listen(
        (snap) {
          feedbackDocs = snap.docs;
          emit();
        },
        onError: (e) {
          debugPrint('Admin Analytics feedback error: $e');
          feedbackDocs = [];
          emit();
        },
      ),
    );

    subscriptions.add(
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('appInstalls')
          .snapshots()
          .listen(
        (snap) {
          installsDocs = snap.docs;
          emit();
        },
        onError: (e) {
          debugPrint('Admin Analytics appInstalls error: $e');
          installsDocs = [];
          emit();
        },
      ),
    );

    subscriptions.add(
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('screenTime')
          .snapshots()
          .listen(
        (snap) {
          screenTimeDocs = snap.docs;
          emit();
        },
        onError: (e) {
          debugPrint('Admin Analytics screenTime error: $e');
          screenTimeDocs = [];
          emit();
        },
      ),
    );

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }
}

class _AdminAnalyticsData {
  final int totalSessions;
  final int upcomingSessions;
  final int completedSessions;

  final int totalUsers;
  final int admins;
  final int speakers;
  final int staff;
  final int attendees;
  final int activeUsers;

  final int totalAttendance;
  final int totalNoShow;

  final int totalMessages;
  final int usersWhoChatted;
  final int engagementRate;
  final int avgMessagesPerUser;

  final int appDownloads;
  final int avgScreenTimeMinutes;
  final String peakActivityHour;

  final double averageRating;

  final Map<int, int> messagesByDay;
  final Map<int, int> messagesByHour;
  final List<_AttendancePoint> attendanceTrend;

  const _AdminAnalyticsData({
    required this.totalSessions,
    required this.upcomingSessions,
    required this.completedSessions,
    required this.totalUsers,
    required this.admins,
    required this.speakers,
    required this.staff,
    required this.attendees,
    required this.activeUsers,
    required this.totalAttendance,
    required this.totalNoShow,
    required this.totalMessages,
    required this.usersWhoChatted,
    required this.engagementRate,
    required this.avgMessagesPerUser,
    required this.appDownloads,
    required this.avgScreenTimeMinutes,
    required this.peakActivityHour,
    required this.averageRating,
    required this.messagesByDay,
    required this.messagesByHour,
    required this.attendanceTrend,
  });

  factory _AdminAnalyticsData.empty() {
    return const _AdminAnalyticsData(
      totalSessions: 0,
      upcomingSessions: 0,
      completedSessions: 0,
      totalUsers: 0,
      admins: 0,
      speakers: 0,
      staff: 0,
      attendees: 0,
      activeUsers: 0,
      totalAttendance: 0,
      totalNoShow: 0,
      totalMessages: 0,
      usersWhoChatted: 0,
      engagementRate: 0,
      avgMessagesPerUser: 0,
      appDownloads: 0,
      avgScreenTimeMinutes: 0,
      peakActivityHour: '-',
      averageRating: 0,
      messagesByDay: {},
      messagesByHour: {},
      attendanceTrend: [],
    );
  }

  factory _AdminAnalyticsData.fromDocs({
    required String eventId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> usersDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> messagesDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> checkInsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> feedbackDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> installsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> screenTimeDocs,
  }) {
    final now = DateTime.now();

    final linkedEventUserIds = <String>{};

    for (final doc in sessionsDocs) {
      final data = doc.data();

      _addUserId(linkedEventUserIds, data['speakerId']);
      _addUserId(linkedEventUserIds, data['hostId']);
      _addUserId(linkedEventUserIds, data['presenterId']);
      _addUserIds(linkedEventUserIds, data['speakerIds']);
      _addUserIds(linkedEventUserIds, data['speakerUIDs']);
      _addUserIds(linkedEventUserIds, data['staffIds']);
    }

    for (final doc in checkInsDocs) {
      final data = doc.data();
      _addUserId(linkedEventUserIds, data['userId']);
      _addUserId(linkedEventUserIds, data['uid']);
      _addUserId(linkedEventUserIds, data['attendeeId']);
    }

    for (final doc in messagesDocs) {
      final data = doc.data();
      _addUserId(linkedEventUserIds, data['senderId']);
      _addUserId(linkedEventUserIds, data['userId']);
      _addUserId(linkedEventUserIds, data['uid']);
    }

    for (final doc in installsDocs) {
      final data = doc.data();
      _addUserId(linkedEventUserIds, data['userId']);
      _addUserId(linkedEventUserIds, data['uid']);
      linkedEventUserIds.add(doc.id);
    }

    for (final doc in screenTimeDocs) {
      final data = doc.data();
      _addUserId(linkedEventUserIds, data['userId']);
      _addUserId(linkedEventUserIds, data['uid']);
      linkedEventUserIds.add(doc.id);
    }

    final eventUsersDocs = usersDocs.where((doc) {
      final data = doc.data();

      return _userBelongsToEvent(
            userId: doc.id,
            data: data,
            eventId: eventId,
          ) ||
          linkedEventUserIds.contains(doc.id);
    }).toList();

    int admins = 0;
    int speakers = 0;
    int staff = 0;
    int attendees = 0;
    int activeUsers = 0;

    for (final doc in eventUsersDocs) {
      final data = doc.data();
      final role = _normalizeRole(data);

      if (role == 'admin') {
        admins++;
      } else if (role == 'speaker') {
        speakers++;
      } else if (role == 'staff') {
        staff++;
      } else {
        attendees++;
      }

      final isActive = data['isActive'] == true ||
          data['status'] == 'active' ||
          _isTimestampWithinLastMinutes(data['lastActiveAt'], 30) ||
          _isTimestampWithinLastMinutes(data['lastSeenAt'], 30) ||
          _isTimestampWithinLastMinutes(data['updatedAt'], 30);

      if (isActive) activeUsers++;
    }

    int upcomingSessions = 0;
    int completedSessions = 0;

    final sessionIds = <String>[];

    for (final doc in sessionsDocs) {
      sessionIds.add(doc.id);

      final data = doc.data();
      final endTime =
          _readDate(data['endTime'] ?? data['endAt'] ?? data['endDate']);
      final startTime =
          _readDate(data['startTime'] ?? data['startAt'] ?? data['startDate']);

      final status = (data['status'] ?? '').toString().toLowerCase();

      if (status == 'completed') {
        completedSessions++;
      } else if (endTime != null && endTime.isBefore(now)) {
        completedSessions++;
      } else if (startTime != null && startTime.isAfter(now)) {
        upcomingSessions++;
      } else if (status == 'upcoming') {
        upcomingSessions++;
      }
    }

    final totalUsers = eventUsersDocs.length;
    final totalSessions = sessionsDocs.length;

    final eventUserIds = eventUsersDocs.map((doc) => doc.id).toSet();

    final attendancePerSession = <String, int>{};

    for (final doc in checkInsDocs) {
      final data = doc.data();

      final userId = (data['userId'] ?? data['uid'] ?? data['attendeeId'] ?? '')
          .toString()
          .trim();

      if (userId.isNotEmpty &&
          eventUserIds.isNotEmpty &&
          !eventUserIds.contains(userId)) {
        continue;
      }

      final sessionId = (data['sessionId'] ??
              data['sessionID'] ??
              data['checkedInSessionId'] ??
              '')
          .toString();

      if (sessionId.isNotEmpty) {
        attendancePerSession[sessionId] =
            (attendancePerSession[sessionId] ?? 0) + 1;
      }
    }

    final totalAttendance = attendancePerSession.values.fold<int>(
      0,
      (previous, value) => previous + value,
    );

    final expectedAttendance = totalSessions * attendees;
    final totalNoShow = expectedAttendance > totalAttendance
        ? expectedAttendance - totalAttendance
        : 0;

    final messagesByDay = <int, int>{};
    final messagesByHour = <int, int>{};
    final chattingUsers = <String>{};

    for (final doc in messagesDocs) {
      final data = doc.data();

      final senderId =
          (data['senderId'] ?? data['userId'] ?? data['uid'] ?? '').toString();

      if (senderId.isNotEmpty &&
          eventUserIds.isNotEmpty &&
          !eventUserIds.contains(senderId)) {
        continue;
      }

      if (senderId.isNotEmpty) chattingUsers.add(senderId);

      final createdAt =
          _readDate(data['createdAt'] ?? data['timestamp'] ?? data['sentAt']);

      if (createdAt != null) {
        messagesByDay[createdAt.weekday] =
            (messagesByDay[createdAt.weekday] ?? 0) + 1;
        messagesByHour[createdAt.hour] =
            (messagesByHour[createdAt.hour] ?? 0) + 1;
      }
    }

    final totalMessages = messagesByDay.values.fold<int>(
      0,
      (previous, value) => previous + value,
    );

    final usersWhoChatted = chattingUsers.length;

    final engagementRate =
        totalUsers == 0 ? 0 : ((activeUsers / totalUsers) * 100).round();

    final avgMessagesPerUser =
        totalUsers == 0 ? 0 : (totalMessages / totalUsers).round();

    double ratingTotal = 0;
    int ratingCount = 0;

    for (final doc in feedbackDocs) {
      final data = doc.data();

      final rating = data['rating'] ??
          data['averageRating'] ??
          data['score'] ??
          data['stars'];

      if (rating is num) {
        ratingTotal += rating.toDouble();
        ratingCount++;
      }
    }

    final averageRating = ratingCount == 0 ? 0.0 : ratingTotal / ratingCount;

    double totalScreenMinutes = 0;

    for (final doc in screenTimeDocs) {
      final data = doc.data();

      final userId = (data['userId'] ?? data['uid'] ?? doc.id).toString();

      if (userId.isNotEmpty &&
          eventUserIds.isNotEmpty &&
          !eventUserIds.contains(userId)) {
        continue;
      }

      final minutes = data['minutes'];
      final seconds = data['seconds'];

      if (minutes is num) {
        totalScreenMinutes += minutes.toDouble();
      } else if (seconds is num) {
        totalScreenMinutes += seconds.toDouble() / 60;
      }
    }

    final avgScreenTimeMinutes = screenTimeDocs.isEmpty
        ? 0
        : (totalScreenMinutes / screenTimeDocs.length).round();

    String peakActivityHour = '-';

    if (messagesByHour.isNotEmpty) {
      final peakHour = messagesByHour.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

      peakActivityHour = _formatHourRange(peakHour);
    }

    final attendanceTrend = <_AttendancePoint>[];

    for (int i = 0; i < sessionIds.length; i++) {
      final sessionId = sessionIds[i];

      attendanceTrend.add(
        _AttendancePoint(
          label: 'S${i + 1}',
          value: attendancePerSession[sessionId] ?? 0,
        ),
      );
    }

    return _AdminAnalyticsData(
      totalSessions: totalSessions,
      upcomingSessions: upcomingSessions,
      completedSessions: completedSessions,
      totalUsers: totalUsers,
      admins: admins,
      speakers: speakers,
      staff: staff,
      attendees: attendees,
      activeUsers: activeUsers,
      totalAttendance: totalAttendance,
      totalNoShow: totalNoShow,
      totalMessages: totalMessages,
      usersWhoChatted: usersWhoChatted,
      engagementRate: engagementRate,
      avgMessagesPerUser: avgMessagesPerUser,
      appDownloads: installsDocs.length,
      avgScreenTimeMinutes: avgScreenTimeMinutes,
      peakActivityHour: peakActivityHour,
      averageRating: averageRating,
      messagesByDay: messagesByDay,
      messagesByHour: messagesByHour,
      attendanceTrend: attendanceTrend,
    );
  }

  static void _addUserId(Set<String> ids, dynamic value) {
    if (value == null) return;

    final id = value.toString().trim();

    if (id.isNotEmpty) {
      ids.add(id);
    }
  }

  static void _addUserIds(Set<String> ids, dynamic value) {
    if (value == null) return;

    if (value is Iterable) {
      for (final item in value) {
        if (item is Map) {
          _addUserId(ids, item['id']);
          _addUserId(ids, item['uid']);
          _addUserId(ids, item['userId']);
        } else {
          _addUserId(ids, item);
        }
      }
    }
  }

  static bool _userBelongsToEvent({
    required String userId,
    required Map<String, dynamic> data,
    required String eventId,
  }) {
    bool valueMatches(dynamic value) {
      if (value == null) return false;

      if (value is String) {
        return value.trim() == eventId;
      }

      if (value is Iterable) {
        for (final item in value) {
          if (item is String && item.trim() == eventId) {
            return true;
          }

          if (item is Map) {
            final id = item['id'] ??
                item['eventId'] ??
                item['eventID'] ??
                item['event_id'];

            if (id != null && id.toString().trim() == eventId) {
              return true;
            }
          }
        }
      }

      if (value is Map) {
        final id = value['id'] ??
            value['eventId'] ??
            value['eventID'] ??
            value['event_id'];

        if (id != null && id.toString().trim() == eventId) {
          return true;
        }

        if (value.containsKey(eventId)) {
          return true;
        }
      }

      return false;
    }

    return valueMatches(data['eventId']) ||
        valueMatches(data['eventID']) ||
        valueMatches(data['activeEventId']) ||
        valueMatches(data['currentEventId']) ||
        valueMatches(data['assignedEventId']) ||
        valueMatches(data['eventIds']) ||
        valueMatches(data['registeredEventIds']) ||
        valueMatches(data['joinedEventIds']) ||
        valueMatches(data['events']) ||
        valueMatches(data['registeredEvents']) ||
        valueMatches(data['assignedEvents']) ||
        valueMatches(data['speakerEventIds']) ||
        valueMatches(data['staffEventIds']) ||
        valueMatches(data['attendeeEventIds']);
  }

  static String _normalizeRole(Map<String, dynamic> data) {
    final rawRole = (data['role'] ??
            data['userRole'] ??
            data['userType'] ??
            data['type'] ??
            'attendee')
        .toString()
        .trim()
        .toLowerCase();

    if (rawRole == 'administrator') return 'admin';
    if (rawRole == 'admins') return 'admin';
    if (rawRole == 'speaker_user') return 'speaker';
    if (rawRole == 'staff_user') return 'staff';
    if (rawRole == 'user') return 'attendee';

    return rawRole;
  }

  static bool _isTimestampWithinLastMinutes(dynamic value, int minutes) {
    final date = _readDate(value);
    if (date == null) return false;

    return DateTime.now().difference(date).inMinutes <= minutes;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _formatHourRange(int hour) {
    final start = _formatHour(hour);
    final end = _formatHour((hour + 1) % 24);
    return '$start - $end';
  }

  static String _formatHour(int hour) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    return '$displayHour:00 $suffix';
  }
}

class _AttendancePoint {
  final String label;
  final int value;

  const _AttendancePoint({
    required this.label,
    required this.value,
  });
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
        color: AppColors.namaNavyBlue,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconBackground,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(13),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 35,
            width: 35,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.2,
              color: AppColors.namaMediumGray,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRolesCard extends StatelessWidget {
  const _UserRolesCard({
    required this.data,
  });

  final _AdminAnalyticsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(13),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 35,
            width: 35,
            decoration: BoxDecoration(
              color: const Color(0xFFE9E7FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppColors.namaNavyBlue,
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.namaDarkGray,
                height: 1.28,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Roles',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.namaMediumGray,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('Admins: ${data.admins}'),
                  Text('Speakers: ${data.speakers}'),
                  Text('Staff: ${data.staff}'),
                  Text('Attendees: ${data.attendees}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.namaNavyBlue,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.namaMediumGray,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AttendancePieChart extends StatelessWidget {
  const _AttendancePieChart({
    required this.attended,
    required this.noShow,
  });

  final int attended;
  final int noShow;

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 42,
        sections: [
          if (attended > 0)
            PieChartSectionData(
              color: AppColors.namaNavyBlue,
              value: attended.toDouble(),
              title: '$attended\nAttended',
              radius: 62,
              titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (noShow > 0)
            PieChartSectionData(
              color: AppColors.namaGoldenYellow,
              value: noShow.toDouble(),
              title: '$noShow\nNo-show',
              radius: 62,
              titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.namaNavyBlue,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatActivityBarChart extends StatelessWidget {
  const _ChatActivityBarChart({
    required this.values,
  });

  final Map<int, int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.values.isEmpty
        ? 1.0
        : values.values.reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue + (maxValue * 0.25),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = {
                  1: 'Mon',
                  2: 'Tue',
                  3: 'Wed',
                  4: 'Thu',
                  5: 'Fri',
                  6: 'Sat',
                  7: 'Sun',
                };

                final dayNumber = value.toInt() + 1;

                return Text(
                  days[dayNumber] ?? '',
                  style: const TextStyle(fontSize: 8),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          final weekday = index + 1;
          final value = values[weekday] ?? 0;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value.toDouble(),
                color: AppColors.namaNavyBlue,
                width: 10,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _EngagementGauge extends StatelessWidget {
  const _EngagementGauge({
    required this.percentage,
  });

  final int percentage;

  @override
  Widget build(BuildContext context) {
    final safePercentage = percentage.clamp(0, 100);

    return Stack(
      children: [
        PieChart(
          PieChartData(
            startDegreeOffset: -90,
            sectionsSpace: 0,
            centerSpaceRadius: 36,
            sections: [
              PieChartSectionData(
                color: AppColors.namaGoldenYellow,
                value: safePercentage.toDouble(),
                title: '',
                radius: 24,
              ),
              PieChartSectionData(
                color: AppColors.namaLightGray,
                value: (100 - safePercentage).toDouble(),
                title: '',
                radius: 24,
              ),
            ],
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$safePercentage%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.namaNavyBlue,
                ),
              ),
              const Text(
                'Active',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.namaMediumGray,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessagesAreaChart extends StatelessWidget {
  const _MessagesAreaChart({
    required this.values,
  });

  final Map<int, int> values;

  @override
  Widget build(BuildContext context) {
    final sortedHours = values.keys.toList()..sort();

    final spots = <FlSpot>[];

    for (int i = 0; i < sortedHours.length; i++) {
      final hour = sortedHours[i];
      spots.add(FlSpot(i.toDouble(), (values[hour] ?? 0).toDouble()));
    }

    final maxValue = values.values.isEmpty
        ? 1.0
        : values.values.reduce((a, b) => a > b ? a : b).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: Color(0xFFEAEAEA),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: sortedHours.length <= 5 ? 1 : 2,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                if (index < 0 || index >= sortedHours.length) {
                  return const SizedBox.shrink();
                }

                return Text(
                  _formatSmallHour(sortedHours[index]),
                  style: const TextStyle(fontSize: 8),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: spots.isEmpty ? 1 : (spots.length - 1).toDouble(),
        minY: 0,
        maxY: maxValue + (maxValue * 0.25),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.namaNavyBlue,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.namaNavyBlue.withOpacity(0.18),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatSmallHour(int hour) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    return '$displayHour$suffix';
  }
}

class _AttendanceLineChart extends StatelessWidget {
  const _AttendanceLineChart({
    required this.values,
  });

  final List<_AttendancePoint> values;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];

    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i].value.toDouble()));
    }

    final maxValue = values.isEmpty
        ? 1.0
        : values.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: Color(0xFFEAEAEA),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: values.length <= 6 ? 1 : 2,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                if (index < 0 || index >= values.length) {
                  return const SizedBox.shrink();
                }

                return Text(
                  values[index].label,
                  style: const TextStyle(fontSize: 8),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: spots.isEmpty ? 1 : (spots.length - 1).toDouble(),
        minY: 0,
        maxY: maxValue + (maxValue * 0.25),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.namaGoldenYellow,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3.5,
                  color: AppColors.namaGoldenYellow,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

class _RadarPerformanceChart extends StatelessWidget {
  const _RadarPerformanceChart({
    required this.data,
  });

  final _AdminAnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final attendanceScore = data.totalUsers == 0
        ? 0.0
        : (data.totalAttendance / data.totalUsers) * 100;

    final ratingScore =
        data.averageRating == 0 ? 0.0 : (data.averageRating / 5) * 100;

    final chatScore = data.totalUsers == 0
        ? 0.0
        : ((data.usersWhoChatted / data.totalUsers) * 100);

    final feedbackScore = ratingScore;

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        radarBorderData: const BorderSide(
          color: Color(0xFFEAEAEA),
          width: 1.5,
        ),
        gridBorderData: const BorderSide(
          color: Color(0xFFEAEAEA),
          width: 1,
        ),
        ticksTextStyle: const TextStyle(
          fontSize: 8,
          color: Colors.transparent,
        ),
        radarBackgroundColor: Colors.transparent,
        titlePositionPercentageOffset: 0.18,
        getTitle: (index, angle) {
          const titles = [
            'Attendance',
            'Engagement',
            'Chat',
            'Feedback',
            'Rating',
          ];

          return RadarChartTitle(
            text: titles[index],
            angle: angle,
          );
        },
        dataSets: [
          RadarDataSet(
            fillColor: AppColors.namaNavyBlue.withOpacity(0.26),
            borderColor: AppColors.namaNavyBlue,
            borderWidth: 2,
            dataEntries: [
              RadarEntry(value: _safePercent(attendanceScore)),
              RadarEntry(value: _safePercent(data.engagementRate.toDouble())),
              RadarEntry(value: _safePercent(chatScore)),
              RadarEntry(value: _safePercent(feedbackScore)),
              RadarEntry(value: _safePercent(ratingScore)),
            ],
          ),
        ],
        titleTextStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.namaDarkGray,
        ),
      ),
    );
  }

  static double _safePercent(double value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }
}

class _DetailedMetricsCard extends StatelessWidget {
  const _DetailedMetricsCard({
    required this.data,
  });

  final _AdminAnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final attendanceRate = data.totalUsers == 0
        ? 0
        : ((data.totalAttendance / data.totalUsers) * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Metrics',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.namaNavyBlue,
            ),
          ),
          const SizedBox(height: 12),
          _MetricRow(
            label: 'Total Attendance',
            value: '${data.totalAttendance} / ${data.totalUsers}',
            extra: '$attendanceRate%',
          ),
          const Divider(height: 20),
          _MetricRow(
            label: 'Total Messages',
            value: _formatNumber(data.totalMessages),
          ),
          const Divider(height: 20),
          _MetricRow(
            label: 'Users Who Chatted',
            value: data.usersWhoChatted.toString(),
          ),
          const Divider(height: 20),
          _MetricRow(
            label: 'Avg. Messages/User',
            value: data.avgMessagesPerUser.toString(),
          ),
          const Divider(height: 20),
          _MetricRow(
            label: 'Peak Activity Time',
            value: data.peakActivityHour,
          ),
          const Divider(height: 20),
          _MetricRow(
            label: 'Average Rating',
            value: data.averageRating == 0
                ? '-'
                : '${data.averageRating.toStringAsFixed(1)} / 5.0',
            extra: data.averageRating == 0
                ? ''
                : _buildStars(data.averageRating),
          ),
        ],
      ),
    );
  }

  static String _buildStars(double rating) {
    final filled = rating.round().clamp(0, 5);
    return '★' * filled + '☆' * (5 - filled);
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.extra = '',
  });

  final String label;
  final String value;
  final String extra;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.namaDarkGray,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.namaNavyBlue,
          ),
        ),
        if (extra.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            extra,
            style: TextStyle(
              fontSize: 10.5,
              color: extra.contains('★')
                  ? AppColors.namaGoldenYellow
                  : AppColors.namaMediumGray,
            ),
          ),
        ],
      ],
    );
  }
}

class _PeakActivityCard extends StatelessWidget {
  const _PeakActivityCard({
    required this.data,
  });

  final _AdminAnalyticsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.namaGoldenYellow,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peak User Activity',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.namaMediumGray,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.peakActivityHour,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Most users active during this hour',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.namaMediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartText extends StatelessWidget {
  const _EmptyChartText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.namaMediumGray,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

String _formatNumber(int value) {
  if (value < 1000) return value.toString();

  final text = value.toString();
  final buffer = StringBuffer();

  for (int i = 0; i < text.length; i++) {
    final indexFromEnd = text.length - i;
    buffer.write(text[i]);

    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}