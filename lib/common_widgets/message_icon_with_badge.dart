import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Message icon with unread count badge
/// Shows a small badge with the number of conversations with unread messages
class MessageIconWithBadge extends ConsumerWidget {
  const MessageIconWithBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadConversationsCountProvider);

    return unreadCountAsync.when(
      data: (count) {
        if (count == 0) {
          return const Icon(Icons.message_outlined);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.message_outlined),
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.errorRed,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: AppColors.namaWhite,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Icon(Icons.message_outlined),
      error: (_, __) => const Icon(Icons.message_outlined),
    );
  }
}
