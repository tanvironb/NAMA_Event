// lib/features/notifications/screen/widgets/notification_list_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';

class NotificationListTile extends ConsumerWidget {
  final AppNotification notification;
  const NotificationListTile({super.key, required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the enum's extension methods for consistent styling
    final iconData = notification.type.icon;
    final iconBackgroundColor = notification.isRead 
        ? Colors.grey.shade300 
        : notification.type.color;
    final iconColor = notification.isRead 
        ? Colors.grey.shade600 
        : Colors.white;

    final timeAgo = DateFormat.yMMMd().add_jm().format(notification.timestamp.toDate());
    
    return Container(
      color: notification.isRead 
        ? Theme.of(context).colorScheme.surface.withOpacity(0.3)
        : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconBackgroundColor,
          child: Icon(iconData, color: iconColor),
        ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          color: notification.isRead 
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.body,
            style: TextStyle(
              color: notification.isRead 
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeAgo, 
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: notification.isRead 
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
      onTap: () {
        final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
        if (userId != null && !notification.isRead) {
          ref.read(notificationRepositoryProvider).markAsRead(userId, notification.id);
        }
        // TODO: Add deep linking logic based on notification.data
      },
    ),
    );
  }
}