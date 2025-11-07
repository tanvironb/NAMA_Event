import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/speaker/screen/widget/speaker_session_detail_screen.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_card_widget.dart';

class MySessionsScreen extends ConsumerWidget {
  const MySessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSessionsAsync = ref.watch(sessionsStreamProvider);
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Sessions')),
      body: allSessionsAsync.when(
        data: (allSessions) {
          final mySessions = allSessions.where((s) => s.speakerIds.contains(userId)).toList();
          if (mySessions.isEmpty) {
            return const Center(child: Text('You are not assigned to any sessions.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: mySessions.length,
            itemBuilder: (context, index) {
              final session = mySessions[index];
              // Use optimized session card widget
              return SessionCardWidget(
                key: ValueKey(session.id), // Add key for better performance
                session: session,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => SpeakerSessionDetailScreen(session: session),
                  ));
                },
              );
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}