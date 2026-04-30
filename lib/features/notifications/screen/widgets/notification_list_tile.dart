import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/notifications/screen/widgets/notification_detail_view.dart';
import 'package:events_app_trueattempt/features/meetings/screen/my_meetings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

class NotificationListTile extends ConsumerWidget {
  final AppNotification notification;
  const NotificationListTile({super.key, required this.notification});

  String _formatEventTimestamp(DateTime eventTime, bool includeDate) {
    if (includeDate) {
      final format = DateFormat('MMM d, yyyy • h:mm a');
      return format.format(eventTime);
    } else {
      final format = DateFormat('h:mm a');
      return format.format(eventTime);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.errorRed;
      case 'medium':
        return AppColors.warningAmber;
      case 'low':
        return AppColors.infoBlue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconData = notification.type.icon;

    final iconBg = notification.isRead
        ? Colors.grey.shade300
        : notification.type.color;

    final iconColor = notification.isRead
        ? Colors.grey.shade600
        : Colors.white;

    final timeAgo =
        DateFormat.yMMMd().add_jm().format(notification.timestamp.toDate());

    final priorityColor = _getPriorityColor(notification.priority);

    return Container(
      color: notification.isRead
          ? Theme.of(context).colorScheme.surface.withOpacity(0.25)
          : null,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // 🔥 tighter

        leading: CircleAvatar(
          radius: 18, // 🔥 smaller icon
          backgroundColor: iconBg,
          child: Icon(iconData, size: 16, color: iconColor),
        ),

        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: 13, // 🔥 reduced
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.w600,
            color: notification.isRead
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.subtitle != null &&
                notification.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                notification.subtitle!,
                style: TextStyle(
                  fontSize: 11, // 🔥 reduced
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(height: 3),

            Text(
              notification.body,
              style: TextStyle(
                fontSize: 12, // 🔥 reduced
                color: notification.isRead
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
              ),
            ),

            const SizedBox(height: 5),

            if (notification.eventTimestamp != null) ...[
              Row(
                children: [
                  Icon(Icons.event, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatEventTimestamp(
                          notification.eventTimestamp!,
                          notification.includeDate),
                      style: TextStyle(
                        fontSize: 10, // 🔥 reduced
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: notification.isRead
                        ? Colors.grey.shade300
                        : priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: notification.isRead
                          ? Colors.grey.shade400
                          : priorityColor.withOpacity(0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        notification.priority == 'high'
                            ? Icons.priority_high
                            : notification.priority == 'medium'
                                ? Icons.circle
                                : Icons.keyboard_arrow_down,
                        size: 10, // 🔥 smaller
                        color: notification.isRead
                            ? Colors.grey.shade600
                            : priorityColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        notification.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9, // 🔥 reduced
                          fontWeight: FontWeight.bold,
                          color: notification.isRead
                              ? Colors.grey.shade600
                              : priorityColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 10, // 🔥 reduced
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        onTap: () {
          final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
          if (userId != null && !notification.isRead) {
            ref
                .read(notificationRepositoryProvider)
                .markAsRead(userId, notification.id);
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  NotificationDetailView(notification: notification),
            ),
          );
        },
      ),
    );
  }
}