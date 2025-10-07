// lib/features/profile/screen/widgets/speaker_sessions_bookmark_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

/// A specialized widget for booking all sessions by a speaker.
/// Follows the app's architecture by handling data logic in the data layer.
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
        if (sessions.isEmpty) {
          return const SizedBox.shrink();
        }

        return currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) return const SizedBox.shrink();
            
            // Check bookmark status for all sessions
            final unbookmarkedSessions = sessions.where((session) =>
              !currentUser.bookmarkedSessions.contains(session.id)
            ).toList();

            // Show different UI based on bookmark status
            if (unbookmarkedSessions.isEmpty) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: null, // Disabled since all are bookmarked
                  icon: const Icon(Icons.bookmark, color: AppColors.goldenYellow),
                  label: Text('All ${sessions.length} Sessions Bookmarked'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.goldenYellow),
                  ),
                ),
              );
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _bookAllSessions(context, unbookmarkedSessions, currentUser.uid, ref),
                icon: const Icon(Icons.bookmark_add),
                label: Text('Book ${unbookmarkedSessions.length} Session${unbookmarkedSessions.length == 1 ? '' : 's'}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaGoldenYellow,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            );
          },
          loading: () => Container(
            width: double.infinity,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => Container(
        width: double.infinity,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _bookAllSessions(BuildContext context, List<Session> sessions, String userId, WidgetRef ref) async {
    final repo = ref.read(userProfileRepositoryProvider);
    
    try {
      // Show loading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Booking sessions...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Use bulk update for better performance - data layer handles the logic
      final sessionIds = sessions.map((session) => session.id).toList();
      await repo.bulkUpdateUserBookmarks(userId, sessionIds, true);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Successfully booked ${sessions.length} session${sessions.length == 1 ? '' : 's'}!'),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Failed to book sessions')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}