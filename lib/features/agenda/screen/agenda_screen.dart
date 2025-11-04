import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/session_list_tile.dart';

// AgendaScreen displays the list of sessions grouped by day for the active event.
class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream of sessions from Firestore
    final sessionsAsyncValue = ref.watch(sessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Agenda'),
      ),
      body: sessionsAsyncValue.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions scheduled yet.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          // Sort sessions by startTime
          final sortedSessions = List<Session>.from(sessions)
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          // Group sessions by day
          final groupedSessions = groupBy(sortedSessions, (Session session) {
            return DateFormat('yyyy-MM-dd').format(session.startTime);
          });

          return AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: groupedSessions.length,
              itemBuilder: (context, dayIndex) {
                final dayKey = groupedSessions.keys.elementAt(dayIndex);
                final daySessions = groupedSessions[dayKey]!;
                final dayDate = DateTime.parse(dayKey);
                
                return AnimationConfiguration.staggeredList(
                  position: dayIndex,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
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
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading agenda',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
    final isToday = _isToday(date);
    final dayName = DateFormat('EEEE').format(date);
    final dayDate = DateFormat('MMMM d, y').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Container(
          margin: EdgeInsets.only(bottom: 16, top: dayIndex == 0 ? 0 : 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isToday
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: isToday
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isToday ? Icons.today : Icons.calendar_today,
                color: isToday
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isToday
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dayDate,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isToday
                            ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.8)
                            : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TODAY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                '${sessions.length} session${sessions.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isToday
                      ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.8)
                      : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        
        // Sessions for this day
        AnimationLimiter(
          child: Column(
            children: sessions.asMap().entries.map((entry) {
              final index = entry.key;
              final session = entry.value;
              
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: dayIndex * 100),
                child: SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SessionListTile(session: session),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}