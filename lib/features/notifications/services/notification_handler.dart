import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';

class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void handleNotificationTap(RemoteMessage message) {
    final BuildContext? context = navigatorKey.currentContext;

    if (context == null) {
      debugPrint(
        'NotificationHandler: navigator context is null, cannot route.',
      );
      return;
    }

    handleNotificationRoute(context, message);
  }

  static void handleNotificationRoute(
    BuildContext context,
    RemoteMessage message,
  ) {
    final Map<String, dynamic> data = message.data;

    final String type = (data['type'] ?? '').toString().toLowerCase();
    final String sessionId = (data['sessionId'] ?? '').toString();

    if (sessionId.isNotEmpty) {
      _navigateToSessionDetail(context, sessionId);
      return;
    }

    switch (type) {
      case 'livestream':
        _navigateToHome(context);
        break;

      case 'message':
      case 'meeting':
      case 'meetingrequest':
        _navigateToNetworking(context);
        break;

      case 'announcement':
      case 'general':
      case 'notification':
        _navigateToNotifications(context);
        break;

      default:
        _navigateToNotifications(context);
        break;
    }
  }

  static void handleForegroundMessage(
    BuildContext context,
    RemoteMessage message,
  ) {
    showInAppBanner(context, message);
  }

  static void _navigateToSessionDetail(
    BuildContext context,
    String sessionId,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AgendaScreen(),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening related session: $sessionId',
        ),
      ),
    );
  }

  static void _navigateToHome(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
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

  static void showInAppBanner(
    BuildContext context,
    RemoteMessage message,
  ) {
    final RemoteNotification? notification = message.notification;

    final String title =
        notification?.title ??
        message.data['title']?.toString() ??
        'NAMA Events';

    final String body =
        notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        'You have a new notification.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            handleNotificationRoute(context, message);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}