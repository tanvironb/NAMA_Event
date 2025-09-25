// lib/features/agenda/presentation/my_bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/session_list_tile.dart';

class MyBookmarksScreen extends ConsumerWidget {
  const MyBookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookmarks')),
      body: userProfileAsync.when(
        data: (appUser) {
          if (appUser == null || appUser.bookmarkedSessions.isEmpty) {
            return const Center(child: Text('You have no bookmarked sessions.'));
          }
          
          return allSessionsAsync.when(
            data: (allSessions) {
              final bookmarkedSessions = allSessions
                  .where((session) => appUser.bookmarkedSessions.contains(session.id))
                  .toList();
              
              if (bookmarkedSessions.isEmpty) {
                 return const Center(child: Text('Your bookmarked sessions will appear here.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: bookmarkedSessions.length,
                itemBuilder: (context, index) {
                  return SessionListTile(session: bookmarkedSessions[index]);
                },
              );
            },
            loading: () => const LoadingIndicator(),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}