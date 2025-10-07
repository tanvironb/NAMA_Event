// lib/features/profile/screen/widgets/bookmark_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';

/// A reusable bookmark button widget that follows the app's design patterns.
/// Uses the bookmark icon pattern from session_detail_screen.dart with
/// animated transitions and consistent theming.
class BookmarkButton extends ConsumerWidget {
  final String sessionId;
  final String userId;
  final bool isBookmarked;
  final VoidCallback? onPressed;
  final double iconSize;
  final EdgeInsets? padding;

  const BookmarkButton({
    super.key,
    required this.sessionId,
    required this.userId,
    required this.isBookmarked,
    this.onPressed,
    this.iconSize = 32,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      padding: padding,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Icon(
          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          key: ValueKey<bool>(isBookmarked), // Key to trigger animation
          color: isBookmarked ? AppColors.goldenYellow : Theme.of(context).colorScheme.secondary,
          size: iconSize,
        ),
      ),
      onPressed: onPressed ?? () => _defaultOnPressed(ref),
    );
  }

  Future<void> _defaultOnPressed(WidgetRef ref) async {
    final repo = ref.read(userProfileRepositoryProvider);
    await repo.updateUserBookmarks(userId, sessionId, !isBookmarked);
  }
}