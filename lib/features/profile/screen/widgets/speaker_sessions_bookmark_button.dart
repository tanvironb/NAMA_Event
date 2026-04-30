// lib/features/profile/screen/widgets/speaker_sessions_bookmark_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

class SpeakerSessionsBookmarkButton extends ConsumerWidget {
  final String speakerId;

  const SpeakerSessionsBookmarkButton({
    super.key,
    required this.speakerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakerSessionsAsync = ref.watch(speakerSessionsProvider(speakerId));
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return speakerSessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();

        return currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) return const SizedBox.shrink();

            final unbookmarkedSessions = sessions.where((session) =>
                !currentUser.bookmarkedSessions.contains(session.id)).toList();

            // 🔹 ALL BOOKED (FIXED STYLE)
            if (unbookmarkedSessions.isEmpty) {
              return SizedBox(
                width: 240,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.bookmark, size: 16),
                  label: Text(
                    'All ${sessions.length} Sessions',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldenYellow,
                    side: const BorderSide(color: AppColors.goldenYellow),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            }

            // 🔹 BOOK BUTTON (FIXED STYLE)
            return SizedBox(
              width: 240,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => _bookAllSessions(
                    context, unbookmarkedSessions, currentUser.uid, ref),
                icon: const Icon(Icons.bookmark_add, size: 16),
                label: Text(
                  'Book ${unbookmarkedSessions.length} Session${unbookmarkedSessions.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaGoldenYellow,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 40,
            width: 240,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox(
        height: 40,
        width: 240,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _bookAllSessions(
    BuildContext context,
    List<Session> sessions,
    String userId,
    WidgetRef ref,
  ) async {
    final repo = ref.read(userProfileRepositoryProvider);

    try {
      final sessionIds = sessions.map((s) => s.id).toList();
      await repo.bulkUpdateUserBookmarks(userId, sessionIds, true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booked ${sessions.length} sessions'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to book sessions'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}