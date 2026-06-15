import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class MessageIconWithBadge extends ConsumerWidget {
  const MessageIconWithBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadConversationsCountProvider);

    return unreadCountAsync.when(
      data: (count) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.message_outlined,
              color: AppColors.namaNavyBlue,
            ),
            if (count > 0)
              Positioned(
                right: -7,
                top: -7,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.namaGoldenYellow,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Icon(
        Icons.message_outlined,
        color: AppColors.namaNavyBlue,
      ),
      error: (_, __) => const Icon(
        Icons.message_outlined,
        color: AppColors.namaNavyBlue,
      ),
    );
  }
}