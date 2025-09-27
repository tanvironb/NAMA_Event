// lib/core/enums/notification_type.dart
import 'package:flutter/material.dart';

enum AppNotificationType {
  warning,
  important,
  announcement,
  chat,
  reminder,
  generic // Fallback
}

extension AppNotificationTypeExtension on AppNotificationType {
  String get displayName {
    switch (this) {
      case AppNotificationType.warning:
        return 'Warning';
      case AppNotificationType.important:
        return 'Important';
      case AppNotificationType.announcement:
        return 'Announcement';
      case AppNotificationType.chat:
        return 'Chat';
      case AppNotificationType.reminder:
        return 'Reminder';
      case AppNotificationType.generic:
        return 'General';
    }
  }

  // Optional: Add icon support
  IconData get icon {
    switch (this) {
      case AppNotificationType.warning:
        return Icons.warning;
      case AppNotificationType.important:
        return Icons.priority_high;
      case AppNotificationType.announcement:
        return Icons.campaign;
      case AppNotificationType.chat:
        return Icons.chat;
      case AppNotificationType.reminder:
        return Icons.schedule;
      case AppNotificationType.generic:
        return Icons.notifications;
    }
  }

  // Optional: Add color support
  Color get color {
    switch (this) {
      case AppNotificationType.warning:
        return Colors.orange;
      case AppNotificationType.important:
        return Colors.red;
      case AppNotificationType.announcement:
        return Colors.blue;
      case AppNotificationType.chat:
        return Colors.green;
      case AppNotificationType.reminder:
        return Colors.purple;
      case AppNotificationType.generic:
        return Colors.grey;
    }
  }
}