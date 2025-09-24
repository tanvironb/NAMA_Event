import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/session_card.dart';

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsStream = ref.watch(sessionsStreamProvider);

    return sessionsStream.when(
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          return const Center(child: Text('No sessions scheduled yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            final sessionDoc = snapshot.docs[index];
            return SessionCard(sessionDoc: sessionDoc);
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (err, stack) => Center(child: Text('Error loading agenda: $err')),
    );
  }
}