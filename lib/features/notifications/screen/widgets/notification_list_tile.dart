import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/services/notification_handler.dart'
    as central;
import 'package:events_app_trueattempt/features/notifications/screen/notification_detail_screen.dart';

class NotificationListTile extends ConsumerStatefulWidget {
  final AppNotification notification;

  const NotificationListTile({
    super.key,
    required this.notification,
  });

  @override
  ConsumerState<NotificationListTile> createState() =>
      _NotificationListTileState();
}

class _NotificationListTileState
    extends ConsumerState<NotificationListTile> {
  bool _responding = false;
  String? _localStatus;

  AppNotification get notification => widget.notification;

  String get _meetingId =>
      (notification.data['meetingId'] ?? '').toString().trim();

  String get _status =>
      (_localStatus ?? notification.data['status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();

  bool get _canRespond {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    final recipientId =
        (notification.data['recipientId'] ?? '').toString();

    return uid != null &&
        _meetingId.isNotEmpty &&
        recipientId == uid &&
        _status == 'pending';
  }

  Color get _priorityColor {
    switch (notification.priority) {
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

  void _openDetails() {
    // Use the same handler as phone-banner taps.
    //
    // Supply the personal notification document ID so the handler
    // opens this exact notification using the shared details screen.
    final payload = <String, dynamic>{
      ...notification.data,
      'notificationId': notification.id,
      'type': _meetingId.isNotEmpty
          ? 'meeting_request'
          : 'admin_notification',
    };

    if (_meetingId.isNotEmpty) {
      payload['meetingId'] = _meetingId;
    }

    central.NotificationHandler.handleNotificationTap(
      RemoteMessage(data: payload),
    );
  }

  Future<void> _respond(String status) async {
    if (_responding) return;

    setState(() {
      _responding = true;
    });

    try {
      await NotificationDetailScreen.respondToMeeting(
        meetingId: _meetingId,
        status: status,
        notificationId: notification.id,
      );

      if (!mounted) return;

      setState(() {
        _localStatus = status;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'accepted'
                ? 'Meeting request approved.'
                : 'Meeting request rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to respond: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _responding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final read = notification.isRead;
    final priorityColor = _priorityColor;

    final timestamp = DateFormat.yMMMd().add_jm().format(
          notification.timestamp.toDate(),
        );

    return Container(
      color: read
          ? Theme.of(context).colorScheme.surface.withOpacity(0.25)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor:
              read ? Colors.grey.shade300 : notification.type.color,
          child: Icon(
            notification.type.icon,
            size: 16,
            color: read ? Colors.grey.shade600 : Colors.white,
          ),
        ),
        title: Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: read ? FontWeight.normal : FontWeight.w600,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(read ? 0.6 : 1),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((notification.subtitle ?? '').trim().isNotEmpty) ...[
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(read ? 0.5 : 0.8),
              ),
            ),
            if (_canRespond) ...[
              const SizedBox(height: 8),
              if (_responding)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _respond('accepted'),
                      icon: const Icon(
                        Icons.check_rounded,
                        size: 15,
                      ),
                      label: const Text(
                        'Approve',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _respond('declined'),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 15,
                      ),
                      label: const Text(
                        'Reject',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
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
                      DateFormat(
                        notification.includeDate
                            ? 'MMM d, yyyy • h:mm a'
                            : 'h:mm a',
                      ).format(notification.eventTimestamp!),
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
                    color: read
                        ? Colors.grey.shade300
                        : priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: read
                          ? Colors.grey.shade400
                          : priorityColor.withOpacity(0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        notification.priority == 'high'
                            ? Icons.priority_high
                            : notification.priority == 'medium'
                                ? Icons.circle
                                : Icons.keyboard_arrow_down,
                        size: 10,
                        color: read
                            ? Colors.grey.shade600
                            : priorityColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        notification.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: read
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
                    timestamp,
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
        onTap: _openDetails,
      ),
    );
  }
}