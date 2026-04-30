import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class NotificationDetailView extends ConsumerStatefulWidget {
  final AppNotification notification;

  const NotificationDetailView({
    super.key,
    required this.notification,
  });

  @override
  ConsumerState<NotificationDetailView> createState() =>
      _NotificationDetailViewState();
}

class _NotificationDetailViewState
    extends ConsumerState<NotificationDetailView> {
  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    if (!widget.notification.isRead) {
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (userId != null) {
        await ref
            .read(notificationRepositoryProvider)
            .markAsRead(userId, widget.notification.id);
      }
    }
  }

  Color get _priorityColor {
    switch (widget.notification.priority) {
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

  IconData get _priorityIcon {
    switch (widget.notification.priority) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.circle;
      case 'low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.notifications;
    }
  }

  String _formatEventTimestamp() {
    if (widget.notification.eventTimestamp == null) return '';

    final eventTime = widget.notification.eventTimestamp!;

    if (widget.notification.includeDate) {
      return DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(eventTime);
    } else {
      return DateFormat('h:mm a').format(eventTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat('MMMM d, yyyy • h:mm a').format(
      widget.notification.timestamp.toDate(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.namaNavyBlue,
          ),
        ),
        backgroundColor: _priorityColor.withOpacity(0.08),
        foregroundColor: AppColors.namaNavyBlue,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: AppColors.namaNavyBlue,
          size: 22,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _priorityColor.withOpacity(0.08),
                    _priorityColor.withOpacity(0.04),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: _priorityColor.withOpacity(0.25),
                    width: 1.4,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: widget.notification.type.color.withOpacity(0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.notification.type.color,
                            width: 1.6,
                          ),
                        ),
                        child: Icon(
                          widget.notification.type.icon,
                          color: widget.notification.type.color,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.notification.type.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.notification.type.color,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _priorityColor.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _priorityColor,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _priorityIcon,
                                    size: 11,
                                    color: _priorityColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${widget.notification.priority.toUpperCase()} PRIORITY',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _priorityColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    widget.notification.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: AppColors.namaNavyBlue,
                      height: 1.25,
                    ),
                  ),

                  if (widget.notification.subtitle != null &&
                      widget.notification.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      widget.notification.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.notification.eventTimestamp != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.namaNavyBlue.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.namaNavyBlue.withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                size: 17,
                                color: AppColors.namaNavyBlue.withOpacity(0.7),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                widget.notification.includeDate
                                    ? 'Event Time'
                                    : 'Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      AppColors.namaNavyBlue.withOpacity(0.75),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _formatEventTimestamp(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.namaNavyBlue,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.namaNavyBlue,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      widget.notification.body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.namaNavyBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}