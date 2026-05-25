import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/meetings/screen/my_meetings_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notification_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class NotificationListTile extends ConsumerWidget {
  final AppNotification notification;

  const NotificationListTile({
    super.key,
    required this.notification,
  });

  String _formatEventTimestamp(DateTime eventTime, bool includeDate) {
    if (includeDate) {
      return DateFormat('MMM d, yyyy • h:mm a').format(eventTime);
    }

    return DateFormat('h:mm a').format(eventTime);
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

  Future<void> _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final userId = ref.read(firebaseAuthProvider).currentUser?.uid;

    if (userId != null && !notification.isRead) {
      await ref
          .read(notificationRepositoryProvider)
          .markAsRead(userId, notification.id);
    }

    final notificationType = notification.type.toString().split('.').last;
    final dataType = (notification.data['type'] ?? '').toString();

    if (notificationType == 'meeting' || dataType == 'meeting') {
      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MyMeetingsScreen(),
        ),
      );
      return;
    }

    final sessionId = (notification.data['sessionId'] ?? '').toString();

    if (sessionId.isNotEmpty) {
      try {
        final sessionDoc = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionId)
            .get();

        if (sessionDoc.exists && context.mounted) {
          final session = Session.fromFirestore(sessionDoc);

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionChatScreen(session: session),
            ),
          );
          return;
        }
      } catch (_) {
        // If session cannot be loaded, open normal notification details.
      }
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          notification: notification,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconData = notification.type.icon;

    final iconBg =
        notification.isRead ? Colors.grey.shade300 : notification.type.color;

    final iconColor = notification.isRead ? Colors.grey.shade600 : Colors.white;

    final timeAgo = DateFormat.yMMMd().add_jm().format(
          notification.timestamp.toDate(),
        );

    final priorityColor = _getPriorityColor(notification.priority);

    return Container(
      color: notification.isRead
          ? Theme.of(context).colorScheme.surface.withOpacity(0.25)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: iconBg,
          child: Icon(
            iconData,
            size: 16,
            color: iconColor,
          ),
        ),
        title: Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
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
                notification.subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                notification.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 3),
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
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
            if (notification.hasQrData) ...[
              Row(
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    size: 12,
                    color: AppColors.namaNavyBlue,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      notification.sessionCode.isNotEmpty
                          ? 'QR available • ${notification.sessionCode}'
                          : 'QR available',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.namaNavyBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (notification.eventTimestamp != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatEventTimestamp(
                        notification.eventTimestamp!,
                        notification.includeDate,
                      ),
                      style: TextStyle(
                        fontSize: 10,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                        size: 10,
                        color: notification.isRead
                            ? Colors.grey.shade600
                            : priorityColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        notification.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
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
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(context, ref),
      ),
    );
  }
}