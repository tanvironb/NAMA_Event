// lib/features/web_admin/screens/admin_web_dashboard_screen.dart

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../admin_web_theme.dart';

class AdminWebDashboardScreen extends StatefulWidget {
  final ValueChanged<String>? onNavigate;

  const AdminWebDashboardScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<AdminWebDashboardScreen> createState() =>
      _AdminWebDashboardScreenState();
}

class _AdminWebDashboardScreenState
    extends State<AdminWebDashboardScreen> {
  int _attendanceDays = 7;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  void _openEvents() {
    widget.onNavigate?.call('Events');
  }

  Stream<int> _collectionCountStream(String collection) {
    return _firestore
        .collection(collection)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _activeEventsCountStream() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      return snapshot.docs.where((document) {
        final data = document.data();
        final status =
            (data['status'] ?? '').toString().trim().toLowerCase();

        return status != 'archived' &&
            data['isArchived'] != true &&
            data['archivedAt'] == null;
      }).length;
    });
  }

  Stream<int> _roleCountStream(String role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _attendanceCountStream() {
    return _firestore
        .collectionGroup('checkins')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _eventsStream() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      final documents = snapshot.docs.where((document) {
        final data = document.data();
        final status =
            (data['status'] ?? '').toString().trim().toLowerCase();

        return status != 'archived' &&
            data['isArchived'] != true &&
            data['archivedAt'] == null;
      }).toList();

      documents.sort((first, second) {
        final firstDate = _readDate(
          first.data(),
          const ['startDate', 'date', 'createdAt'],
        );
        final secondDate = _readDate(
          second.data(),
          const ['startDate', 'date', 'createdAt'],
        );

        return firstDate.compareTo(secondDate);
      });

      return documents;
    });
  }

  Stream<List<_TopSessionItem>> _topSessionsStream() {
    return _firestore.collection('sessions').snapshots().asyncMap(
      (snapshot) async {
        final items = <_TopSessionItem>[];

        for (final document in snapshot.docs) {
          final data = document.data();

          var feedbackCount = _readInt(
            data,
            const [
              'totalFeedbacks',
              'feedbackCount',
              'totalFeedback',
              'ratingsCount',
            ],
          );

          if (feedbackCount == 0) {
            try {
              final feedbackSnapshot = await document.reference
                  .collection('feedback')
                  .count()
                  .get();

              feedbackCount = feedbackSnapshot.count ?? 0;
            } catch (_) {
              feedbackCount = 0;
            }
          }

          final joinedCount = _readListCount(
            data,
            const [
              'checkedInAttendees',
              'joinedUserIds',
              'attendeeIds',
              'participants',
              'participantIds',
              'registeredUserIds',
            ],
            fallbackKeys: const [
              'checkedInCount',
              'joinedCount',
              'attendanceCount',
              'participantCount',
            ],
          );

          final averageRating =
              (data['averageRating'] as num?)?.toDouble() ?? 0;

          items.add(
            _TopSessionItem(
              id: document.id,
              data: data,
              feedbackCount: feedbackCount,
              joinedCount: joinedCount,
              averageRating: averageRating,
            ),
          );
        }

        items.sort((first, second) {
          final feedbackComparison =
              second.feedbackCount.compareTo(first.feedbackCount);

          if (feedbackComparison != 0) {
            return feedbackComparison;
          }

          final joinedComparison =
              second.joinedCount.compareTo(first.joinedCount);

          if (joinedComparison != 0) {
            return joinedComparison;
          }

          final ratingComparison =
              second.averageRating.compareTo(first.averageRating);

          if (ratingComparison != 0) {
            return ratingComparison;
          }

          final firstDate = _readDate(
            first.data,
            const ['date', 'startDate', 'startTime', 'createdAt'],
          );
          final secondDate = _readDate(
            second.data,
            const ['date', 'startDate', 'startTime', 'createdAt'],
          );

          return secondDate.compareTo(firstDate);
        });

        return items.take(6).toList();
      },
    );
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _ticketsStream() {
    return _firestore
        .collection('help_tickets')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<int>> _attendanceByDayStream(int numberOfDays) {
    return _firestore
        .collectionGroup('checkins')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start =
          today.subtract(Duration(days: numberOfDays - 1));

      final counts = List<int>.filled(numberOfDays, 0);

      for (final document in snapshot.docs) {
        final data = document.data();
        final date = _readDate(
          data,
          const [
            'checkedInAt',
            'checkInAt',
            'timestamp',
            'createdAt',
            'updatedAt',
          ],
        );

        if (date.millisecondsSinceEpoch == 0 ||
            date.isBefore(start)) {
          continue;
        }

        final normalized =
            DateTime(date.year, date.month, date.day);
        final index = normalized.difference(start).inDays;

        if (index >= 0 && index < counts.length) {
          counts[index]++;
        }
      }

      return counts;
    });
  }

  static DateTime _readDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;

      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int _readInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is num) {
        return value.toInt();
      }
    }

    return 0;
  }

  static int _readListCount(
    Map<String, dynamic> data,
    List<String> listKeys, {
    List<String> fallbackKeys = const [],
  }) {
    for (final key in listKeys) {
      final value = data[key];

      if (value is List) {
        return value.length;
      }
    }

    return _readInt(data, fallbackKeys);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminWebTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          children: [
            _DashboardDateBar(
              numberOfDays: _attendanceDays,
              onChanged: (value) {
                setState(() => _attendanceDays = value);
              },
            ),
            const SizedBox(height: 14),
            _StatsRow(
              eventsStream: _activeEventsCountStream(),
              usersStream: _collectionCountStream('users'),
              sessionsStream: _collectionCountStream('sessions'),
              speakersStream: _roleCountStream('speaker'),
              attendanceStream: _attendanceCountStream(),
              onOpenEvents: _openEvents,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      SizedBox(
                        height: 340,
                        child: _AttendanceOverviewCard(
                          attendanceStream:
                              _attendanceByDayStream(_attendanceDays),
                          numberOfDays: _attendanceDays,
                          onRangeChanged: (value) {
                            setState(() => _attendanceDays = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 330,
                        child: _UpcomingEventsCard(
                          eventsStream: _eventsStream(),
                          onViewAll: _openEvents,
                          onOpenEvent: _openEvents,
                        ),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  height: 330,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 11,
                        child: _AttendanceOverviewCard(
                          attendanceStream:
                              _attendanceByDayStream(_attendanceDays),
                          numberOfDays: _attendanceDays,
                          onRangeChanged: (value) {
                            setState(() => _attendanceDays = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 10,
                        child: _UpcomingEventsCard(
                          eventsStream: _eventsStream(),
                          onViewAll: _openEvents,
                          onOpenEvent: _openEvents,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      SizedBox(
                        height: 390,
                        child: _TopSessionsCard(
                          sessionsStream: _topSessionsStream(),
                          onViewAll: _openEvents,
                          onOpenSession: _openEvents,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 390,
                        child: _HelpOverviewCard(
                          ticketsStream: _ticketsStream(),
                          onViewAll: _openEvents,
                        ),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  height: 390,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 13,
                        child: _TopSessionsCard(
                          sessionsStream: _topSessionsStream(),
                          onViewAll: _openEvents,
                          onOpenSession: _openEvents,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 9,
                        child: _HelpOverviewCard(
                          ticketsStream: _ticketsStream(),
                          onViewAll: _openEvents,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const _DashboardFooter(),
          ],
        ),
      ),
    );
  }
}

class _TopSessionItem {
  final String id;
  final Map<String, dynamic> data;
  final int feedbackCount;
  final int joinedCount;
  final double averageRating;

  const _TopSessionItem({
    required this.id,
    required this.data,
    required this.feedbackCount,
    required this.joinedCount,
    required this.averageRating,
  });
}

class _DashboardDateBar extends StatelessWidget {
  final int numberOfDays;
  final ValueChanged<int> onChanged;

  const _DashboardDateBar({
    required this.numberOfDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start =
        now.subtract(Duration(days: numberOfDays - 1));
    final formatter = DateFormat('MMM d');

    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<int>(
        tooltip: 'Change dashboard date range',
        initialValue: numberOfDays,
        onSelected: onChanged,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 7,
            child: Text('Last 7 days'),
          ),
          PopupMenuItem(
            value: 14,
            child: Text('Last 14 days'),
          ),
          PopupMenuItem(
            value: 30,
            child: Text('Last 30 days'),
          ),
        ],
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AdminWebTheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AdminWebTheme.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatter.format(start)} – '
                  '${formatter.format(now)}, ${now.year}',
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Stream<int> eventsStream;
  final Stream<int> usersStream;
  final Stream<int> sessionsStream;
  final Stream<int> speakersStream;
  final Stream<int> attendanceStream;
  final VoidCallback onOpenEvents;

  const _StatsRow({
    required this.eventsStream,
    required this.usersStream,
    required this.sessionsStream,
    required this.speakersStream,
    required this.attendanceStream,
    required this.onOpenEvents,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = 5;

        if (constraints.maxWidth < 650) {
          columns = 1;
        } else if (constraints.maxWidth < 1000) {
          columns = 2;
        } else if (constraints.maxWidth < 1250) {
          columns = 3;
        }

        const spacing = 12.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Total Events',
                subtitle: 'Open event management',
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF1662F4),
                iconBackground: const Color(0xFFE7F0FF),
                stream: eventsStream,
                onTap: onOpenEvents,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Total Users',
                subtitle: 'Manage event users',
                icon: Icons.group_outlined,
                iconColor: const Color(0xFF0AA65B),
                iconBackground: const Color(0xFFE5F8ED),
                stream: usersStream,
                onTap: onOpenEvents,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Total Sessions',
                subtitle: 'Manage event sessions',
                icon: Icons.web_asset_rounded,
                iconColor: const Color(0xFF7545F6),
                iconBackground: const Color(0xFFF0EAFE),
                stream: sessionsStream,
                onTap: onOpenEvents,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Speakers',
                subtitle: 'Manage event speakers',
                icon: Icons.person_outline_rounded,
                iconColor: const Color(0xFFFF8708),
                iconBackground: const Color(0xFFFFF0DF),
                stream: speakersStream,
                onTap: onOpenEvents,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                title: 'Attendance',
                subtitle: 'Open event attendance',
                icon: Icons.show_chart_rounded,
                iconColor: const Color(0xFFF1435A),
                iconBackground: const Color(0xFFFFE7EB),
                stream: attendanceStream,
                onTap: onOpenEvents,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Stream<int> stream;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.stream,
    required this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(
          0,
          _hovered ? -3 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: _hovered
                ? widget.iconColor.withOpacity(0.35)
                : AdminWebTheme.border,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.iconColor.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 112,
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  children: [
                    Container(
                      width: 49,
                      height: 49,
                      decoration: BoxDecoration(
                        color: widget.iconBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.iconColor,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: widget.stream,
                        builder: (context, snapshot) {
                          final value = snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? '...'
                              : snapshot.hasError
                                  ? '0'
                                  : NumberFormat.decimalPattern()
                                      .format(snapshot.data ?? 0);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Color(0xFF1A2A4A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  AnimatedOpacity(
                                    opacity: _hovered ? 1 : 0,
                                    duration:
                                        const Duration(milliseconds: 160),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: widget.iconColor,
                                      size: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF09132D),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.subtitle,
                                style: TextStyle(
                                  color: widget.iconColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AdminWebTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  const _CardHeader({
    required this.title,
    this.actionLabel = 'View All',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0A1733),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (onAction != null)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0046E5),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
            ),
            label: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AttendanceOverviewCard extends StatelessWidget {
  final Stream<List<int>> attendanceStream;
  final int numberOfDays;
  final ValueChanged<int> onRangeChanged;

  const _AttendanceOverviewCard({
    required this.attendanceStream,
    required this.numberOfDays,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Attendance Overview',
                  style: TextStyle(
                    color: Color(0xFF0A1733),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<int>(
                initialValue: numberOfDays,
                onSelected: onRangeChanged,
                tooltip: 'Change attendance range',
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 7,
                    child: Text('Last 7 days'),
                  ),
                  PopupMenuItem(
                    value: 14,
                    child: Text('Last 14 days'),
                  ),
                  PopupMenuItem(
                    value: 30,
                    child: Text('Last 30 days'),
                  ),
                ],
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    height: 28,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AdminWebTheme.border),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      children: [
                        Text(
                          numberOfDays == 7
                              ? 'This Week'
                              : 'Last $numberOfDays Days',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: StreamBuilder<List<int>>(
              stream: attendanceStream,
              builder: (context, snapshot) {
                final values = snapshot.data ??
                    List<int>.filled(numberOfDays, 0);

                final maxValue =
                    math.max(5, values.fold<int>(0, math.max))
                        .toDouble();

                final now = DateTime.now();
                final start =
                    DateTime(now.year, now.month, now.day)
                        .subtract(
                  Duration(days: numberOfDays - 1),
                );

                final xInterval = numberOfDays <= 7
                    ? 1.0
                    : numberOfDays <= 14
                        ? 2.0
                        : 5.0;

                return LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (numberOfDays - 1).toDouble(),
                    minY: 0,
                    maxY: maxValue * 1.25,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            final date = start.add(
                              Duration(days: spot.x.toInt()),
                            );

                            return LineTooltipItem(
                              '${DateFormat('MMM d').format(date)}\n'
                              '${spot.y.toInt()} check-in'
                              '${spot.y.toInt() == 1 ? '' : 's'}',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval:
                          math.max(1, maxValue / 4),
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(
                        color: Color(0xFFE8ECF3),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          interval: math.max(1, maxValue / 4),
                          getTitlesWidget: (value, _) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Color(0xFF506083),
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: xInterval,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();

                            if (index < 0 ||
                                index >= numberOfDays ||
                                index % xInterval.toInt() != 0) {
                              return const SizedBox.shrink();
                            }

                            final date = start.add(
                              Duration(days: index),
                            );

                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: 8),
                              child: Text(
                                numberOfDays <= 7
                                    ? DateFormat('EEE d').format(date)
                                    : DateFormat('MMM d').format(date),
                                style: const TextStyle(
                                  color: Color(0xFF506083),
                                  fontSize: 8.5,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        curveSmoothness: 0.25,
                        color: const Color(0xFF0B5CF3),
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: numberOfDays <= 14,
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF0B5CF3),
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF0B5CF3)
                              .withOpacity(0.10),
                        ),
                        spots: List.generate(
                          values.length,
                          (index) => FlSpot(
                            index.toDouble(),
                            values[index].toDouble(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventsCard extends StatelessWidget {
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      eventsStream;
  final VoidCallback onViewAll;
  final VoidCallback onOpenEvent;

  const _UpcomingEventsCard({
    required this.eventsStream,
    required this.onViewAll,
    required this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(17, 13, 17, 12),
      child: Column(
        children: [
          _CardHeader(
            title: 'Upcoming Events',
            onAction: onViewAll,
          ),
          const SizedBox(height: 7),
          Expanded(
            child: StreamBuilder<
                List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: eventsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AdminWebTheme.primary,
                    ),
                  );
                }

                final now = DateTime.now();

                final events = (snapshot.data ?? []).where((document) {
                  final date =
                      _AdminWebDashboardScreenState._readDate(
                    document.data(),
                    const ['endDate', 'startDate', 'date'],
                  );

                  return date.isAfter(
                        now.subtract(const Duration(days: 1)),
                      ) ||
                      document.data()['isActive'] == true;
                }).take(4).toList();

                if (events.isEmpty) {
                  return const Center(
                    child: Text(
                      'No upcoming events',
                      style: TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  );
                }

                return Column(
                  children: events.map((document) {
                    return Expanded(
                      child: _UpcomingEventRow(
                        data: document.data(),
                        onTap: onOpenEvent,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _UpcomingEventRow({
    required this.data,
    required this.onTap,
  });

  @override
  State<_UpcomingEventRow> createState() =>
      _UpcomingEventRowState();
}

class _UpcomingEventRowState extends State<_UpcomingEventRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final name =
        (data['name'] ?? data['title'] ?? 'Unnamed Event')
            .toString();
    final location = (data['location'] ?? '').toString();

    final start = _AdminWebDashboardScreenState._readDate(
      data,
      const ['startDate', 'date', 'createdAt'],
    );

    final end = _AdminWebDashboardScreenState._readDate(
      data,
      const ['endDate', 'startDate', 'date'],
    );

    final isActive = data['isActive'] == true;

    final status =
        (data['status'] ?? (isActive ? 'ongoing' : 'upcoming'))
            .toString();

    final imageUrl =
        (data['imageUrl'] ?? data['coverImageUrl'] ?? '')
            .toString();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? AdminWebTheme.primary.withOpacity(0.035)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFEDF0F5),
                ),
              ),
            ),
            child: Row(
              children: [
                _SmallImage(
                  imageUrl: imageUrl,
                  fallbackIcon: Icons.event_rounded,
                  width: 57,
                  height: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0A1733),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location.isEmpty
                            ? 'Location not set'
                            : location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF687691),
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  status: status,
                  active: isActive,
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: Color(0xFF687691),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 115,
                  child: Text(
                    _formatDateRange(start, end),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF506083),
                      fontSize: 8.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AdminWebTheme.primary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDateRange(
    DateTime start,
    DateTime end,
  ) {
    if (start.millisecondsSinceEpoch == 0) {
      return 'Date not set';
    }

    final startText = DateFormat('MMM d').format(start);
    final endText = DateFormat('MMM d, yyyy').format(end);

    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return DateFormat('MMM d, yyyy').format(start);
    }

    return '$startText – $endText';
  }
}

class _TopSessionsCard extends StatelessWidget {
  final Stream<List<_TopSessionItem>> sessionsStream;
  final VoidCallback onViewAll;
  final VoidCallback onOpenSession;

  const _TopSessionsCard({
    required this.sessionsStream,
    required this.onViewAll,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        children: [
          _CardHeader(
            title: 'Top Sessions',
            actionLabel: 'Open Events',
            onAction: onViewAll,
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ranked by feedback responses, joined attendees, and average rating.',
              style: TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 8.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _MiniTableHeader(
            columns: [
              _MiniColumn('SESSION', 5),
              _MiniColumn('FEEDBACK', 2),
              _MiniColumn('JOINED', 2),
              _MiniColumn('RATING', 2),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<_TopSessionItem>>(
              stream: sessionsStream,
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AdminWebTheme.primary,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load top sessions',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }

                if (sessions.isEmpty) {
                  return const Center(
                    child: Text(
                      'No sessions found',
                      style: TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                }

                return Column(
                  children: List.generate(
                    sessions.length,
                    (index) => Expanded(
                      child: _TopSessionRow(
                        rank: index + 1,
                        item: sessions[index],
                        onTap: onOpenSession,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _BottomLink(
            label: 'Open Events to Manage Sessions',
            onTap: onViewAll,
          ),
        ],
      ),
    );
  }
}

class _TopSessionRow extends StatefulWidget {
  final int rank;
  final _TopSessionItem item;
  final VoidCallback onTap;

  const _TopSessionRow({
    required this.rank,
    required this.item,
    required this.onTap,
  });

  @override
  State<_TopSessionRow> createState() => _TopSessionRowState();
}

class _TopSessionRowState extends State<_TopSessionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.item.data;

    final title =
        (data['title'] ?? data['name'] ?? 'Untitled Session')
            .toString();

    final eventName =
        (data['eventName'] ?? data['eventTitle'] ?? 'Event')
            .toString();

    final imageUrl =
        (data['imageUrl'] ?? data['sessionImageUrl'] ?? '')
            .toString();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? AdminWebTheme.primary.withOpacity(0.035)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFEDF0F5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.rank <= 3
                              ? AdminWebTheme.gold.withOpacity(0.16)
                              : const Color(0xFFF0F3F8),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${widget.rank}',
                          style: TextStyle(
                            color: widget.rank <= 3
                                ? const Color(0xFF8A6500)
                                : AdminWebTheme.textSecondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      _SmallImage(
                        imageUrl: imageUrl,
                        fallbackIcon: Icons.mic_none_rounded,
                        width: 31,
                        height: 31,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 8.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              eventName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF687691),
                                fontSize: 7.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _NumberMetric(
                    icon: Icons.rate_review_outlined,
                    value: '${widget.item.feedbackCount}',
                    tooltip: 'Feedback responses',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _NumberMetric(
                    icon: Icons.how_to_reg_outlined,
                    value: '${widget.item.joinedCount}',
                    tooltip: 'Joined/check-in count',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _NumberMetric(
                    icon: Icons.star_rounded,
                    value: widget.item.averageRating <= 0
                        ? '—'
                        : widget.item.averageRating
                            .toStringAsFixed(1),
                    tooltip: 'Average rating',
                    highlighted: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String tooltip;
  final bool highlighted;

  const _NumberMetric({
    required this.icon,
    required this.value,
    required this.tooltip,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 12,
            color: highlighted
                ? AdminWebTheme.gold
                : AdminWebTheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF25324A),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpOverviewCard extends StatelessWidget {
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      ticketsStream;
  final VoidCallback onViewAll;

  const _HelpOverviewCard({
    required this.ticketsStream,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          _CardHeader(
            title: 'Help Center Overview',
            actionLabel: 'Open Events',
            onAction: onViewAll,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<
                List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: ticketsStream,
              builder: (context, snapshot) {
                final tickets = snapshot.data ?? [];

                final counts = <String, int>{
                  TicketStatus.pending: 0,
                  TicketStatus.critical: 0,
                  TicketStatus.processing: 0,
                  TicketStatus.processed: 0,
                  TicketStatus.spam: 0,
                };

                for (final document in tickets) {
                  final status = (document.data()['status'] ??
                          TicketStatus.pending)
                      .toString()
                      .trim()
                      .toLowerCase();

                  if (counts.containsKey(status)) {
                    counts[status] = counts[status]! + 1;
                  }
                }

                final total = counts.values.fold<int>(
                  0,
                  (sum, value) => sum + value,
                );

                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      enabled: true,
                                      touchCallback: (_, __) {},
                                    ),
                                    centerSpaceRadius: 42,
                                    sectionsSpace: 1,
                                    startDegreeOffset: -90,
                                    sections: [
                                      _pieSection(
                                        counts[
                                            TicketStatus.pending]!,
                                        const Color(0xFF4285F4),
                                        total,
                                      ),
                                      _pieSection(
                                        counts[
                                            TicketStatus.critical]!,
                                        const Color(0xFFFF5365),
                                        total,
                                      ),
                                      _pieSection(
                                        counts[
                                            TicketStatus.processing]!,
                                        const Color(0xFFFFA71A),
                                        total,
                                      ),
                                      _pieSection(
                                        counts[
                                            TicketStatus.processed]!,
                                        const Color(0xFF42C7A3),
                                        total,
                                      ),
                                      _pieSection(
                                        counts[TicketStatus.spam]!,
                                        const Color(0xFF8E8E93),
                                        total,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      total.toString(),
                                      style: const TextStyle(
                                        color: Color(0xFF07142D),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        color: Color(0xFF66748D),
                                        fontSize: 8.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                _LegendRow(
                                  label: 'Pending',
                                  value:
                                      counts[TicketStatus.pending]!,
                                  color:
                                      const Color(0xFF4285F4),
                                ),
                                _LegendRow(
                                  label: 'Critical',
                                  value:
                                      counts[TicketStatus.critical]!,
                                  color:
                                      const Color(0xFFFF5365),
                                ),
                                _LegendRow(
                                  label: 'Processing',
                                  value:
                                      counts[TicketStatus.processing]!,
                                  color:
                                      const Color(0xFFFFA71A),
                                ),
                                _LegendRow(
                                  label: 'Processed',
                                  value:
                                      counts[TicketStatus.processed]!,
                                  color:
                                      const Color(0xFF42C7A3),
                                ),
                                _LegendRow(
                                  label: 'Spam',
                                  value: counts[TicketStatus.spam]!,
                                  color:
                                      const Color(0xFF8E8E93),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetricCard(
                            icon: Icons.schedule_rounded,
                            label: 'Avg. Response Time',
                            value: total == 0 ? '0m' : '—',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniMetricCard(
                            icon: Icons.trending_up_rounded,
                            label: 'Resolution Rate',
                            value: total == 0
                                ? '0%'
                                : '${((counts[TicketStatus.processed]! / total) * 100).round()}%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onViewAll,
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                        ),
                        label: const Text(
                          'Select an Event to Manage Help Tickets',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static PieChartSectionData _pieSection(
    int value,
    Color color,
    int total,
  ) {
    return PieChartSectionData(
      value: total == 0 ? 1 : value.toDouble(),
      color: total == 0
          ? const Color(0xFFE8ECF3)
          : color,
      radius: 22,
      showTitle: false,
    );
  }
}

class _MiniTableHeader extends StatelessWidget {
  final List<_MiniColumn> columns;

  const _MiniTableHeader({
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFDDE3EC)),
        ),
      ),
      child: Row(
        children: columns
            .map(
              (column) => Expanded(
                flex: column.flex,
                child: Text(
                  column.label,
                  textAlign: column.label == 'SESSION'
                      ? TextAlign.left
                      : TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF32415F),
                    fontSize: 7.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MiniColumn {
  final String label;
  final int flex;

  const _MiniColumn(this.label, this.flex);
}

class _BottomLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BottomLink({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextButton(
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallImage extends StatelessWidget {
  final String imageUrl;
  final IconData fallbackIcon;
  final double width;
  final double height;
  final bool circular;

  const _SmallImage({
    required this.imageUrl,
    required this.fallbackIcon,
    required this.width,
    required this.height,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(
      circular ? math.max(width, height) : 7,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFFEAF0FA),
        child: imageUrl.trim().isEmpty
            ? Icon(
                fallbackIcon,
                size: math.min(width, height) * 0.48,
                color: AdminWebTheme.primary,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  size: math.min(width, height) * 0.48,
                  color: AdminWebTheme.primary,
                ),
              ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool active;

  const _StatusPill({
    required this.status,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized =
        status.trim().toLowerCase().replaceAll('_', ' ');

    late Color background;
    late Color foreground;
    late String label;

    if (active ||
        normalized == 'ongoing' ||
        normalized == 'active') {
      background = const Color(0xFFE2F7E9);
      foreground = const Color(0xFF0B8C4C);
      label = 'ONGOING';
    } else if (normalized == 'draft') {
      background = const Color(0xFFF0F2F6);
      foreground = const Color(0xFF5A6579);
      label = 'DRAFT';
    } else if (normalized == 'published') {
      background = const Color(0xFFE2F7E9);
      foreground = const Color(0xFF0B8C4C);
      label = 'PUBLISHED';
    } else {
      background = const Color(0xFFE5F0FF);
      foreground = const Color(0xFF0758D9);
      label = normalized.isEmpty
          ? 'UPCOMING'
          : normalized.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 7.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2F3C55),
                fontSize: 8.5,
              ),
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Color(0xFF0A1733),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        border: Border.all(color: AdminWebTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF0ECFF),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 15,
              color: const Color(0xFF6946E8),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF59677E),
                    fontSize: 7.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF134BD4),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

class _DashboardFooter extends StatelessWidget {
  const _DashboardFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AdminWebTheme.border),
        ),
      ),
      child: const Row(
        children: [
          Text(
            '© 2026 NAMA Foundation. All rights reserved.',
            style: TextStyle(
              color: Color(0xFF6B7890),
              fontSize: 9,
            ),
          ),
          Spacer(),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              color: Color(0xFF6B7890),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
