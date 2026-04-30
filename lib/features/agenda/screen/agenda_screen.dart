import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/session_list_tile.dart';


class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsyncValue = ref.watch(sessionsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: sessionsAsyncValue.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text('No sessions scheduled yet.'));
          }

          final sortedSessions = List<Session>.from(sessions)
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          final groupedSessions = groupBy(sortedSessions, (Session session) {
            return DateFormat('yyyy-MM-dd').format(session.startTime);
          });

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              /// 🔥 Floating Title (THIS IS THE FIX)
              SliverAppBar(
  floating: true,
  snap: true,
  backgroundColor: Colors.white.withOpacity(0.92),
  elevation: 0,
  automaticallyImplyLeading: false,
  titleSpacing: 26,
  toolbarHeight: 70,
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
      color: Color(0xFF0B0B83),
      fontSize: 22,
      fontWeight: FontWeight.w800,
    ),
  ),
),

              /// Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(26, 10, 26, 110),
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

  const _DaySection({
    required this.date,
    required this.sessions,
    required this.dayIndex,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('MMMM d, yyyy').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 14, top: dayIndex == 0 ? 0 : 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFC3C1DF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 21),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      DateFormat('EEEE').format(date),
                      style: const TextStyle(
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${sessions.length} Session${sessions.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),

        Column(
          children: sessions.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: SessionListTile(session: session),
            );
          }).toList(),
        ),
      ],
    );
  }
}
//taahmmed123@gmail.com