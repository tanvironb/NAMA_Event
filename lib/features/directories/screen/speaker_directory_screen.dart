// lib/features/directories/presentation/speaker_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/directories/screen/widgets/user_list_tile.dart';

class SpeakerDirectoryScreen extends ConsumerWidget {
  const SpeakerDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakersAsync = ref.watch(speakersFutureProvider);
    return speakersAsync.when(
      data: (speakers) {
        if (speakers.isEmpty) {
          return const Center(child: Text('No speakers to display.'));
        }
        return ListView.builder(
          itemCount: speakers.length,
          itemBuilder: (context, index) => UserListTile(user: speakers[index]),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}