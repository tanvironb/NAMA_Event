// lib/features/directories/presentation/attendee_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/directories/screen/widgets/user_list_tile.dart';

class AttendeeDirectoryScreen extends ConsumerWidget {
  const AttendeeDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendeesAsync = ref.watch(attendeesFutureProvider);
    return attendeesAsync.when(
      data: (attendees) {
        if (attendees.isEmpty) {
          return const Center(child: Text('No attendees to display.'));
        }
        return ListView.builder(
          itemCount: attendees.length,
          itemBuilder: (context, index) => UserListTile(user: attendees[index]),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}