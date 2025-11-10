// lib/core/enums/notification_type.dart
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Notification types with priority-based categorization
/// Admin-sendable: alert, announcement, information, maintenance
/// System-only: chat, meetingRequest, generic
enum AppNotificationType {
  // Admin-sendable types
  alert,           // High priority - Emergency alerts with popup
  announcement,    // Medium priority - General announcements
  information,     // Low priority - General information
  maintenance,     // Medium priority - System maintenance notices
  
  // System-generated only (not sendable by admin)
  chat,            // Chat messages
  meetingRequest,  // Meeting/calendar requests
  generic,         // Fallback
  
  // Legacy types (for backward compatibility)
  @Deprecated('Use alert instead')
  warning,
  @Deprecated('Use announcement instead')
  important,
  @Deprecated('Use information instead')
  reminder,
}

extension AppNotificationTypeExtension on AppNotificationType {
  String get displayName {
    switch (this) {
      case AppNotificationType.alert:
        return 'Alert';
      case AppNotificationType.announcement:
        return 'Announcement';
      case AppNotificationType.information:
        return 'Information';
      case AppNotificationType.maintenance:
        return 'Maintenance';
      case AppNotificationType.chat:
        return 'Chat';
      case AppNotificationType.meetingRequest:
        return 'Meeting Request';
      case AppNotificationType.generic:
        return 'General';
      // Legacy support
      case AppNotificationType.warning:
        return 'Alert';
      case AppNotificationType.important:
        return 'Important';
      case AppNotificationType.reminder:
        return 'Reminder';
    }
  }

  IconData get icon {
    switch (this) {
      case AppNotificationType.alert:
      case AppNotificationType.warning:
        return Icons.warning;
      case AppNotificationType.announcement:
      case AppNotificationType.important:
        return Icons.campaign;
      case AppNotificationType.information:
      case AppNotificationType.reminder:
        return Icons.info_outline;
      case AppNotificationType.maintenance:
        return Icons.build_circle_outlined;
      case AppNotificationType.chat:
        return Icons.chat;
      case AppNotificationType.meetingRequest:
        return Icons.event_available;
      case AppNotificationType.generic:
        return Icons.notifications;
    }
  }

  /// Priority level: high, medium, low
  String get priority {
    switch (this) {
      case AppNotificationType.alert:
      case AppNotificationType.warning:
        return 'high';
      case AppNotificationType.announcement:
      case AppNotificationType.maintenance:
      case AppNotificationType.important:
        return 'medium';
      case AppNotificationType.information:
      case AppNotificationType.chat:
      case AppNotificationType.meetingRequest:
      case AppNotificationType.reminder:
      case AppNotificationType.generic:
        return 'low';
    }
  }

  /// Whether this type shows a popup
  bool get showsPopup {
    return this == AppNotificationType.alert || this == AppNotificationType.warning;
  }

  /// Whether this type can be sent by admins
  bool get isAdminSendable {
    return this == AppNotificationType.alert ||
           this == AppNotificationType.announcement ||
           this == AppNotificationType.information ||
           this == AppNotificationType.maintenance;
  }

  Color get color {
    switch (this) {
      case AppNotificationType.alert:
      case AppNotificationType.warning:
        return AppColors.errorRed;
      case AppNotificationType.announcement:
      case AppNotificationType.important:
        return AppColors.namaNavyBlue;
      case AppNotificationType.maintenance:
        return AppColors.warningAmber;
      case AppNotificationType.information:
      case AppNotificationType.reminder:
        return AppColors.infoBlue;
      case AppNotificationType.chat:
        return AppColors.successGreen;
      case AppNotificationType.meetingRequest:
        return AppColors.namaGoldenYellow;
      case AppNotificationType.generic:
        return AppColors.namaMediumGray;
    }
  }

  /// Priority sorting value (lower = higher priority)
  int get priorityValue {
    switch (priority) {
      case 'high':
        return 0;
      case 'medium':
        return 1;
      case 'low':
        return 2;
      default:
        return 3;
    }
  }
}