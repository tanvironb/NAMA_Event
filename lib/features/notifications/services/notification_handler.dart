// lib/features/notifications/services/notification_handler.dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';

class NotificationHandler {
  static void handleNotificationRoute(BuildContext context, RemoteMessage message) {
    final data = message.data;
    
    if (data.containsKey('sessionId')) {
      _navigateToSessionDetail(context, data['sessionId']);
    } else if (data.containsKey('type')) {
      switch (data['type']) {
        case 'livestream':
          _navigateToHome(context);
          break;
        case 'message':
        case 'meeting':
          _navigateToNetworking(context);
          break;
        case 'announcement':
        case 'general':
          _navigateToNotifications(context);
          break;
        default:
          _navigateToHome(context);
      }
    } else {
      // Default to home for unknown notification types
      _navigateToHome(context);
    }
  }

  static void _navigateToSessionDetail(BuildContext context, String sessionId) {
    // First navigate to agenda, which will handle session lookup
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AgendaScreen(),
      ),
    );
    
    // Show snackbar indicating which session to look for
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Looking for session: $sessionId'),
        action: SnackBarAction(
          label: 'Search',
          onPressed: () {
            // Future enhancement: add search functionality
          },
        ),
      ),
    );
  }

  static void _navigateToHome(BuildContext context) {
    // Pop all routes and go to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void _navigateToNetworking(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DirectoriesHubScreen(),
      ),
    );
  }

  static void _navigateToNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  // Helper method to show in-app notification banner
  static void showInAppBanner(BuildContext context, RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title ?? 'Notification',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (notification.body != null)
              Text(notification.body!),
          ],
        ),
        action: message.data.isNotEmpty ? SnackBarAction(
          label: 'View',
          onPressed: () => handleNotificationRoute(context, message),
        ) : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}