import 'dart:math' as math;
import 'package:events_app_trueattempt/common_widgets/session_statistics_builder.dart';
import 'package:events_app_trueattempt/core/models/session_statistics.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../session_monitoring_repository.dart';
import 'monitoring_ui.dart';

class SessionOverviewTab extends StatelessWidget {
  final SessionMonitoringRepository repository;
  final Map<String, dynamic> data;
  final VoidCallback? onEdit;
  final VoidCallback? onNotification;
  final VoidCallback onQr;
  final VoidCallback onCopy;
  const SessionOverviewTab({
    super.key,
    required this.repository,
    required this.data,
    this.onEdit,
    this.onNotification,
    required this.onQr,
    required this.onCopy,
  });
  static const _primary = Color(0xFF0B0B83);
  static const _gap = 14.0;
  int count(String key) {
    return (data[key] as num?)?.toInt() ?? 0;
  }

  int listCount(String key) {
    final value = data[key];
    return value is List ? value.length : 0;
  }

  String _text(String key, String fallback) {
    final value = (data[key] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SessionStatisticsBuilder(
          sessionId: repository.sessionId,
          firestore: repository.db,
          feedbackPath: repository.feedbackPath,
          builder: (context, stats) => _metrics(stats),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final information = _information();
            final trend = _attendanceTrend();
            final actions = _quickActions();
            final status = _status(context);
            if (constraints.maxWidth >= 760) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        information,
                        const SizedBox(height: _gap),
                        status,
                      ],
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [trend, const SizedBox(height: _gap), actions],
                    ),
                  ),
                ],
              );
            }
            // Mobile: stack panels without horizontal overflow.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                information,
                const SizedBox(height: _gap),
                trend,
                const SizedBox(height: _gap),
                actions,
                const SizedBox(height: _gap),
                status,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _metrics(SessionStatistics? stats) {
    final attended = listCount('checkedInAttendees');
    final feedback = stats?.feedback ?? 0;
    final rating = stats?.averageRating ?? 0;
    final bookmarks = listCount('bookmarkedBy');
    final registered =
        bookmarks > 0 ? bookmarks : listCount('registeredAttendees');
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          _metric(
            icon: Icons.groups_outlined,
            value: '$attended',
            label: 'Checked-in Attendees',
            subtitle:
                registered > 0
                    ? 'of $registered registered'
                    : 'Session attendance',
            color: const Color(0xFF2870FF),
            background: const Color(0xFFEAF2FF),
            progress: registered > 0 ? attended / registered : null,
          ),
          _metric(
            icon: Icons.chat_bubble_outline,
            value: stats == null ? '—' : '$feedback',
            label: 'Feedback Received',
            subtitle: 'Submitted session feedback',
            color: const Color(0xFF00AB68),
            background: const Color(0xFFE9F8F1),
            progress: attended > 0 ? feedback / attended : null,
          ),
          _metric(
            icon: Icons.star_border,
            value: feedback > 0 ? rating.toStringAsFixed(1) : '—',
            label: 'Average Rating',
            subtitle: '$feedback ratings',
            color: const Color(0xFFFFA000),
            background: const Color(0xFFFFF5E7),
            stars: feedback > 0 ? rating : null,
          ),
          _metric(
            icon: Icons.chat_outlined,
            value: stats == null ? '—' : '${stats.messages}',
            label: 'Chat Messages',
            subtitle: 'Messages in this session',
            color: _primary,
            background: const Color(0xFFEEEEFA),
          ),
          _metric(
            icon: Icons.people_outline,
            value: stats == null ? '—' : '${stats.participants}',
            label: 'Chat Participants',
            subtitle: 'Active in this session',
            color: const Color(0xFFFF187B),
            background: const Color(0xFFFFEDF6),
          ),
        ];
        final int columns;
        if (constraints.maxWidth >= 1150) {
          columns = 5;
        } else if (constraints.maxWidth >= 720) {
          columns = 3;
        } else if (constraints.maxWidth >= 460) {
          columns = 2;
        } else {
          columns = 1;
        }
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children:
              cards.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }

  Widget _metric({
    required IconData icon,
    required String value,
    required String label,
    required String subtitle,
    required Color color,
    required Color background,
    double? progress,
    double? stars,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: monitorInk,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: monitorInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: monitorMuted,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      minHeight: 5,
                      color: color,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else if (stars != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(5, (index) {
                final IconData starIcon;
                if (stars >= index + 1) {
                  starIcon = Icons.star;
                } else if (stars >= index + 0.5) {
                  starIcon = Icons.star_half;
                } else {
                  starIcon = Icons.star_border;
                }
                return Icon(starIcon, color: color, size: 18);
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _information() {
    return MonitorPanel(
      title: 'Session Information',
      trailing: TextButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined, size: 15),
        label: const Text('Edit', style: TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          backgroundColor: _primary.withOpacity(0.07),
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('title', 'Session'),
                      style: const TextStyle(
                        color: monitorInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _smallPill(_text('category', 'Other'), _primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _info(
            Icons.calendar_month_outlined,
            'Schedule',
            '${monitorDay(data['startTime'])}\n'
                '${monitorTime(data['startTime'])} – '
                '${monitorTime(data['endTime'])}',
          ),
          const SizedBox(height: 18),
          _info(Icons.location_on_outlined, 'Venue', _text('location', '—')),
          const SizedBox(height: 18),
          _info(
            Icons.description_outlined,
            'Description',
            _text('description', 'No description provided.'),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                color: monitorMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Session Chat', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              _smallPill(
                data['isChatEnabled'] == false ? 'Disabled' : 'Enabled',
                data['isChatEnabled'] == false
                    ? Colors.grey
                    : const Color(0xFF00AA66),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 300;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: monitorMuted, size: 20),
            const SizedBox(width: 10),
            if (narrow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: monitorInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: const TextStyle(
                        color: monitorMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              SizedBox(
                width: 88,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: monitorInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: monitorMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _attendanceTrend() {
    return MonitorPanel(
      title: 'Attendance Trend',
      icon: Icons.bar_chart_rounded,
      trailing: _smallPill('Last recorded hour', _primary),
      child: _LiveAttendanceTrend(repository: repository),
    );
  }

  Widget _quickActions() {
    return MonitorPanel(
      title: 'Quick Actions',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = <Widget>[
            _action(
              Icons.qr_code_2,
              'Show QR Code',
              'For attendee check-in',
              onQr,
            ),
            _action(
              Icons.link,
              'Copy Session Link',
              'Share with attendees',
              onCopy,
            ),
            _action(
              Icons.notifications_outlined,
              'Send Notification',
              'Notify all participants',
              onNotification,
            ),
          ];
          if (constraints.maxWidth < 450) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int index = 0; index < items.length; index++) ...[
                  items[index],
                  if (index < items.length - 1) const SizedBox(height: 8),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int index = 0; index < items.length; index++) ...[
                Expanded(child: items[index]),
                if (index < items.length - 1) const SizedBox(width: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? action,
  ) {
    return Material(
      color: _primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                color: action == null ? monitorMuted : _primary,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: action == null ? monitorMuted : _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: monitorMuted,
                        fontSize: 9.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    final start = monitorDate(data['startTime']);
    final end = monitorDate(data['endTime']);
    final now = DateTime.now();
    final live =
        start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
    final ended = end != null && !now.isBefore(end);
    final label =
        live
            ? 'Session is Live'
            : ended
            ? 'Session has Ended'
            : 'Session is Upcoming';
    return MonitorPanel(
      title: 'Session Status',
      trailing: Text(
        live
            ? '● Active Now'
            : ended
            ? 'Ended'
            : 'Upcoming',
        style: TextStyle(
          color: live ? const Color(0xFF00AA66) : monitorMuted,
          fontSize: 11,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF9F3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Color(0xFF00AA66), size: 25),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF00AA66),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enable or disable session chat',
                    style: TextStyle(
                      color: monitorMuted,
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Switch(
              value: data['isChatEnabled'] != false,
              activeTrackColor: _primary,
              activeThumbColor: Colors.white,
              onChanged: (value) {
                monitorAction(context, () => repository.setChat(value));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        softWrap: true,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

class _LiveAttendanceTrend extends StatefulWidget {
  final SessionMonitoringRepository repository;
  const _LiveAttendanceTrend({required this.repository});

  @override
  State<_LiveAttendanceTrend> createState() => _LiveAttendanceTrendState();
}

class _LiveAttendanceTrendState extends State<_LiveAttendanceTrend> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _checkins;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _checkins = widget.repository.session.collection('checkins').snapshots();
  }

  @override
  void didUpdateWidget(covariant _LiveAttendanceTrend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _checkins,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return monitorEmpty('Unable to load check-ins: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 170,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _Trend(
          records: snapshot.data!.docs.map((doc) => doc.data()).toList(),
        );
      },
    );
  }
}

DateTime? _checkInDate(Map<String, dynamic> record) {
  for (final key in const [
    'checkedInAt',
    'checkInTime',
    'checkinTime',
    'checkInTimestamp',
    'checkinTimestamp',
    'timestamp',
    'createdAt',
  ]) {
    final date = monitorDate(record[key]);
    if (date != null) return date;
  }
  return null;
}

class _Trend extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _Trend({required this.records});
  @override
  Widget build(BuildContext context) {
    final dates =
        records.map(_checkInDate).whereType<DateTime>().toList()..sort();
    if (dates.isEmpty) {
      return SizedBox(
        height: 170,
        child: monitorEmpty('No timestamped check-ins yet.'),
      );
    }
    final end = dates.last;
    final begin = end.subtract(const Duration(minutes: 60));
    final buckets = List<int>.filled(6, 0);
    for (final date in dates) {
      final elapsed = date.difference(begin);
      if (elapsed.isNegative || elapsed > const Duration(minutes: 60)) {
        continue;
      }
      final index = math.min(5, elapsed.inMinutes ~/ 10);
      buckets[index]++;
    }
    final maximum = buckets.fold<int>(
      1,
      (highest, value) => math.max(highest, value),
    );
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(6, (index) {
          final time = begin.add(Duration(minutes: index * 10));
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${buckets[index]}',
                    style: const TextStyle(color: monitorMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Tooltip(
                    message:
                        '${buckets[index]} checked-in • '
                        '${monitorTime(time)}',
                    child: Container(
                      width: double.infinity,
                      height: 112 * buckets[index] / maximum + 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            const Color(0xFF0B0B83).withOpacity(0.30),
                            const Color(0xFF0B0B83).withOpacity(0.80),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      monitorTime(time),
                      style: const TextStyle(color: monitorMuted, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
