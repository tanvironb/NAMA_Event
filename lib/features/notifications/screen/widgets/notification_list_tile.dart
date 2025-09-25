// lib/features/notifications/screen/widgets/notification_list_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class NotificationListTile extends ConsumerWidget {
  final AppNotification notification;
  const NotificationListTile({super.key, required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeAgo = DateFormat.yMMMd().add_jm().format(notification.timestamp.toDate());
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.isRead ? Colors.grey.shade300 : AppColors.goldenYellow,
        child: Icon(
          Icons.campaign,
          color: notification.isRead ? Colors.grey.shade600 : AppColors.darkGray,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          const SizedBox(height: 4),
          Text(timeAgo, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      onTap: () {
        final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
        if (userId != null && !notification.isRead) {
          ref.read(notificationRepositoryProvider).markAsRead(userId, notification.id);
        }
        // TODO: Add deep linking logic based on notification.data
      },
    );
  }
}