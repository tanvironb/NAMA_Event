import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';

class InAppNotificationHandler extends ConsumerWidget {
  final Widget child;
  const InAppNotificationHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationsStreamProvider, (previous, next) {
      final newNotifications = next.asData?.value;
      if (newNotifications == null || newNotifications.isEmpty) return;

      final latestNotification = newNotifications.first;
      // Check if it's a new, unread, warning notification
      if (latestNotification.type == AppNotificationType.warning && !latestNotification.isRead) {
        // Mark as read immediately to prevent re-showing
        final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
        if (userId != null) {
          ref.read(notificationRepositoryProvider).markAsRead(userId, latestNotification.id);
        }

        // Show the dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(latestNotification.title),
              ],
            ),
            content: Text(latestNotification.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    });

    return child;
  }
}