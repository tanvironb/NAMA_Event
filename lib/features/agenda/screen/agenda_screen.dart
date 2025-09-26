import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/session_list_tile.dart'; // Renamed SessionCard

// AgendaScreen displays the list of sessions for the active event.
class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream of sessions from Firestore
    final sessionsAsyncValue = ref.watch(sessionsStreamProvider);

    return sessionsAsyncValue.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Text(
              'No sessions scheduled yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        return AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.all(12.0), // Padding around the list
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: SessionListTile(session: session), // Use the renamed widget
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingIndicator(), // Show loading spinner
      error: (err, stack) => Center(
        child: Text(
          'Error loading agenda: $err',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}