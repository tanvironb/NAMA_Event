import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Notification icon with unread count badge
/// Shows a small badge with the number of unread notifications (excluding chat messages)
class NotificationIconWithBadge extends ConsumerWidget {
  final bool isActive;
  
  const NotificationIconWithBadge({
    super.key,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);

    return unreadCountAsync.when(
      data: (count) {
        final icon = isActive 
            ? const Icon(Icons.notifications)
            : const Icon(Icons.notifications_outlined);
            
        if (count == 0) {
          return icon;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
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
      loading: () => isActive 
          ? const Icon(Icons.notifications)
          : const Icon(Icons.notifications_outlined),
      error: (_, __) => isActive 
          ? const Icon(Icons.notifications)
          : const Icon(Icons.notifications_outlined),
    );
  }
}
