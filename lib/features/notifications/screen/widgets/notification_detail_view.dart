import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';

/// Detail view for admin-sent notifications (alert, announcement, information, maintenance)
/// Shows full notification content in a dedicated screen
class NotificationDetailView extends ConsumerStatefulWidget {
  final AppNotification notification;

  const NotificationDetailView({
    super.key,
    required this.notification,
  });

  @override
  ConsumerState<NotificationDetailView> createState() => _NotificationDetailViewState();
}

class _NotificationDetailViewState extends ConsumerState<NotificationDetailView> {
  @override
  void initState() {
    super.initState();
    // Mark notification as read when opened
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    if (!widget.notification.isRead) {
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (userId != null) {
        await ref.read(notificationRepositoryProvider).markAsRead(
          userId,
          widget.notification.id,
        );
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
      // Show full date + time
      final format = DateFormat('EEEE, MMMM d, yyyy • h:mm a');
      return format.format(eventTime);
    } else {
      // Show time only
      final format = DateFormat('h:mm a');
      return format.format(eventTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat('MMMM d, yyyy • h:mm a').format(
      widget.notification.timestamp.toDate(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification'),
        backgroundColor: _priorityColor.withOpacity(0.1),
        foregroundColor: AppColors.namaDeepNavy,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with priority badge and type icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _priorityColor.withOpacity(0.1),
                    _priorityColor.withOpacity(0.05),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: _priorityColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon and priority badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.notification.type.color.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.notification.type.color,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          widget.notification.type.icon,
                          color: widget.notification.type.color,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type name
                            Text(
                              widget.notification.type.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.notification.type.color,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Priority badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _priorityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _priorityColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _priorityIcon,
                                    size: 14,
                                    color: _priorityColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${widget.notification.priority.toUpperCase()} PRIORITY',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _priorityColor,
                                      letterSpacing: 0.8,
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
                  const SizedBox(height: 20),
                  
                  // Title
                  Text(
                    widget.notification.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.namaDeepNavy,
                      height: 1.3,
                    ),
                  ),
                  
                  // Subtitle (if present)
                  if (widget.notification.subtitle != null &&
                      widget.notification.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.notification.subtitle!,
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Timestamp
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event timestamp (if present)
                  if (widget.notification.eventTimestamp != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.namaDeepNavy.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.namaDeepNavy.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                size: 20,
                                color: AppColors.namaDeepNavy.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.notification.includeDate ? 'Event Time' : 'Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.namaDeepNavy.withOpacity(0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatEventTimestamp(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.namaDeepNavy,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Body content
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.namaDeepNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      widget.notification.body,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: AppColors.namaDeepNavy,
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
