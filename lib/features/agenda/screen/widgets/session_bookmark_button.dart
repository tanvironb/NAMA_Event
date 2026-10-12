import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class SessionBookmarkButton extends ConsumerStatefulWidget {
  final String sessionId;
  final double iconSize;
  final EdgeInsets? padding;
  final Alignment alignment;
  final Color? bookmarkedColor;
  final Color? unbookmarkedColor;

  const SessionBookmarkButton({
    super.key,
    required this.sessionId,
    this.iconSize = 32,
    this.padding,
    this.alignment = Alignment.centerRight,
    this.bookmarkedColor,
    this.unbookmarkedColor,
  });

  @override
  ConsumerState<SessionBookmarkButton> createState() =>
      _SessionBookmarkButtonState();
}

class _SessionBookmarkButtonState
    extends ConsumerState<SessionBookmarkButton> {
  bool _saving = false;

  Future<void> _toggleBookmark(String uid) async {
    if (_saving) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != uid) {
      _showError('Please sign in again to bookmark this session.');
      return;
    }

    setState(() => _saving = true);

    try {
      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(uid);
      final sessionRef =
          db.collection('sessions').doc(widget.sessionId);

      await db.runTransaction<void>((transaction) async {
        // Read both documents before performing any writes.
        final userSnapshot = await transaction.get(userRef);
        final sessionSnapshot = await transaction.get(sessionRef);

        if (!userSnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'profile-not-found',
            message: 'Your user profile could not be found.',
          );
        }

        if (!sessionSnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'session-not-found',
            message: 'This session no longer exists.',
          );
        }

        final userData =
            userSnapshot.data() ?? <String, dynamic>{};
        final sessionData =
            sessionSnapshot.data() ?? <String, dynamic>{};

        final userBookmarks = userData['bookmarkedSessions'];
        final isBookmarked = userBookmarks is List &&
            userBookmarks.contains(widget.sessionId);

        final shouldBookmark = !isBookmarked;

        transaction.update(userRef, <String, dynamic>{
          'bookmarkedSessions': shouldBookmark
              ? FieldValue.arrayUnion([widget.sessionId])
              : FieldValue.arrayRemove([widget.sessionId]),
        });

        final updates = <String, dynamic>{
          'bookmarkedBy': shouldBookmark
              ? FieldValue.arrayUnion([uid])
              : FieldValue.arrayRemove([uid]),
        };

        if (shouldBookmark) {
          final times = sessionData['bookmarkTimes'];

          // Preserve an existing timestamp when available.
          if (times is! Map || times[uid] == null) {
            updates['bookmarkTimes.$uid'] =
                FieldValue.serverTimestamp();
          }
        } else {
          updates['bookmarkTimes.$uid'] = FieldValue.delete();
        }

        transaction.update(sessionRef, updates);
      });
    } on FirebaseException catch (error) {
      _showError(
        error.code == 'permission-denied'
            ? 'Bookmark was not saved. Firestore permissions denied '
                'the update.'
            : error.message ?? 'Unable to save bookmark.',
      );
    } catch (_) {
      _showError('Unable to save bookmark. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync =
        ref.watch(userAppProfileStreamProvider);

    return userProfileAsync.when(
      data: (appUser) {
        if (appUser == null) return const SizedBox.shrink();

        final bookmarkedList = appUser.bookmarkedSessions ?? [];
        final isBookmarked =
            bookmarkedList.contains(widget.sessionId);

        final color = isBookmarked
            ? widget.bookmarkedColor ?? AppColors.goldenYellow
            : widget.unbookmarkedColor ??
                Theme.of(context).colorScheme.secondary;

        return Align(
          alignment: widget.alignment,
          child: IconButton(
            tooltip: isBookmarked
                ? 'Remove bookmark'
                : 'Bookmark session',
            padding: widget.padding ?? EdgeInsets.zero,
            onPressed: _saving
                ? null
                : () => _toggleBookmark(appUser.uid),
            icon: _saving
                ? SizedBox(
                    height: widget.iconSize * 0.65,
                    width: widget.iconSize * 0.65,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Icon(
                      isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      key: ValueKey<bool>(isBookmarked),
                      color: color,
                      size: widget.iconSize,
                    ),
                  ),
          ),
        );
      },
      loading: () => SizedBox(
        height: widget.iconSize,
        width: widget.iconSize,
        child: const LoadingIndicator(),
      ),
      error: (error, stack) => const Tooltip(
        message: 'Unable to load bookmarks.',
        child: Icon(Icons.error_outline, size: 20),
      ),
    );
  }
}