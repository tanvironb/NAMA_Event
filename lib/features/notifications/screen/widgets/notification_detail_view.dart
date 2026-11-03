import 'package:flutter/material.dart';

import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notification_detail_screen.dart';

class NotificationDetailView extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailView({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationDetailScreen(
      notification: notification,
    );
  }
}