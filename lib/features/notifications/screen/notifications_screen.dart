import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/notifications/screen/widgets/notification_list_tile.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// Helper method to get notification priority for sorting
  /// Lower number = higher priority
  int _getNotificationPriority(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.warning:
        return 0; // Highest priority
      case AppNotificationType.important:
        return 1; // Second priority
      case AppNotificationType.chat:
        return 2; // Third priority
      case AppNotificationType.announcement:
        return 3;
      case AppNotificationType.reminder:
        return 4;
      case AppNotificationType.generic:
        return 5; // Lowest priority
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('You have no notifications.'));
          }

          // Enhanced sorting logic: unread status > type priority > timestamp
          notifications.sort((a, b) {
            // First, prioritize unread notifications
            if (a.isRead != b.isRead) {
              return a.isRead ? 1 : -1; // unread first
            }
            
            // Then by type priority
            final aPriority = _getNotificationPriority(a.type);
            final bPriority = _getNotificationPriority(b.type);
            if (aPriority != bPriority) {
              return aPriority.compareTo(bPriority); // lower number = higher priority
            }
            
            // Finally by timestamp (newest first)
            return b.timestamp.compareTo(a.timestamp);
          });

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return NotificationListTile(notification: notifications[index]);
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}