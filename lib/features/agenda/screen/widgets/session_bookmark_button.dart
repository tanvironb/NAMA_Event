// lib/features/agenda/screen/widgets/session_bookmark_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class SessionBookmarkButton extends ConsumerWidget {
  final String sessionId;
  final double iconSize;
  final EdgeInsets? padding;
  final Alignment alignment;

  // NEW: optional custom colors
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
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

    return userProfileAsync.when(
      data: (appUser) {
        if (appUser == null) return const SizedBox.shrink();

        final bookmarkedList = appUser.bookmarkedSessions ?? [];
        final isBookmarked = bookmarkedList.contains(sessionId);

        return Align(
          alignment: alignment,
          child: IconButton(
            padding: padding ?? EdgeInsets.zero,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                key: ValueKey<bool>(isBookmarked),
                color: isBookmarked
                    ? (bookmarkedColor ?? AppColors.goldenYellow)
                    : (unbookmarkedColor ??
                        Theme.of(context).colorScheme.secondary),
                size: iconSize,
              ),
            ),
            onPressed: () => _toggleBookmark(ref, appUser, isBookmarked),
          ),
        );
      },
      loading: () => SizedBox(
        height: iconSize,
        width: iconSize,
        child: const LoadingIndicator(),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Future<void> _toggleBookmark(
    WidgetRef ref,
    AppUser appUser,
    bool isBookmarked,
  ) async {
    final repo = ref.read(userProfileRepositoryProvider);
    await repo.updateUserBookmarks(appUser.uid, sessionId, !isBookmarked);
  }
}