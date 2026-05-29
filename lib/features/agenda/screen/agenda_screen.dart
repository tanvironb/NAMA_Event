import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/agenda/screen/session_detail_screen.dart';
import 'package:events_app_trueattempt/features/staff/screen/staff_session_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  static const Color _primaryColor = Color(0xFF0B0B83);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsyncValue = ref.watch(sessionsStreamProvider);
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

    final role = userProfileAsync.asData?.value?.role.toLowerCase() ?? '';
    final isStaff = role == 'staff';

    return Scaffold(
      backgroundColor: Colors.white,
      body: sessionsAsyncValue.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Text('No sessions scheduled yet.'),
            );
          }

          final sortedSessions = List<Session>.from(sessions)
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          final groupedSessions = groupBy(sortedSessions, (Session session) {
            return DateFormat('yyyy-MM-dd').format(session.startTime);
          });

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: Colors.white.withOpacity(0.92),
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 20,
                toolbarHeight: 58,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ),
                title: const Text(
                  'Event Agenda',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 92),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, dayIndex) {
                      final dayKey = groupedSessions.keys.elementAt(dayIndex);
                      final daySessions = groupedSessions[dayKey]!;
                      final dayDate = DateTime.parse(dayKey);

                      return AnimationConfiguration.staggeredList(
                        position: dayIndex,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 30,
                          child: FadeInAnimation(
                            child: _DaySection(
                              date: dayDate,
                              sessions: daySessions,
                              dayIndex: dayIndex,
                              isStaff: isStaff,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: groupedSessions.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Text('Error loading agenda\n$err'),
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final DateTime date;
  final List<Session> sessions;
  final int dayIndex;
  final bool isStaff;

  const _DaySection({
    required this.date,
    required this.sessions,
    required this.dayIndex,
    required this.isStaff,
  });

  void _openSession(BuildContext context, Session session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          if (isStaff) {
            return StaffSessionManagementScreen(session: session);
          }

          return SessionDetailScreen(session: session);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('MMMM d, yyyy').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 12, top: dayIndex == 0 ? 0 : 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFC3C1DF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: Colors.black87,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE').format(date),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${sessions.length} Session${sessions.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Column(
          children: sessions.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AgendaSessionCard(
                session: session,
                isStaff: isStaff,
                onTap: () => _openSession(context, session),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AgendaSessionCard extends StatelessWidget {
  final Session session;
  final bool isStaff;
  final VoidCallback onTap;

  const _AgendaSessionCard({
    required this.session,
    required this.isStaff,
    required this.onTap,
  });

  static const Color _primaryColor = Color(0xFF0B0B83);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive =
        now.isAfter(session.startTime) && now.isBefore(session.endTime);
    final hasEnded = now.isAfter(session.endTime);

    return Container(
      decoration: BoxDecoration(
        color: hasEnded ? const Color(0xFFF1F1F1) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green : Colors.transparent,
          width: isActive ? 1.5 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(
                    isActive: isActive,
                    hasEnded: hasEnded,
                  ),
                  if (isStaff) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Manage',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('h:mm a').format(session.startTime),
                    style: TextStyle(
                      color: hasEnded ? Colors.grey : _textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasEnded ? Colors.grey.shade600 : _textDark,
                        fontSize: 14.2,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: hasEnded ? Colors.grey : _primaryColor,
                    size: 23,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasEnded ? Colors.grey : _textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${session.checkedInAttendees.length} attended',
                    style: TextStyle(
                      color: hasEnded ? Colors.grey : _textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool hasEnded;

  const _StatusBadge({
    required this.isActive,
    required this.hasEnded,
  });

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;

    if (isActive) {
      text = 'Live';
      color = Colors.green;
    } else if (hasEnded) {
      text = 'Ended';
      color = Colors.grey;
    } else {
      text = 'Upcoming';
      color = const Color(0xFF0B0B83);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}