import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/session_card.dart';

// AgendaScreen displays the list of sessions for the active event.
class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream of sessions from Firestore
    final sessionsStream = ref.watch(sessionsStreamProvider);

    return sessionsStream.when(
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          return Center(
            child: Text(
              'No sessions scheduled yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12.0), // Padding around the list
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            final sessionDoc = snapshot.docs[index];
            return SessionCard(sessionDoc: sessionDoc); // Use the reusable SessionCard
          },
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