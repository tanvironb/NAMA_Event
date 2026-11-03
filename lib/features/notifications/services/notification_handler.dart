import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:events_app_trueattempt/core/services/notification_handler.dart'
    as central;

/// Compatibility wrapper.
///
/// Every notification tap uses the central handler and the same
/// navigator key registered in app.dart.
class NotificationHandler {
  static GlobalKey<NavigatorState> get navigatorKey =>
      central.NotificationHandler.navigatorKey;

  static void setNavigationReady(bool ready) {
    central.NotificationHandler.setNavigationReady(ready);
  }

  static void handleNotificationTap(RemoteMessage message) {
    central.NotificationHandler.handleNotificationTap(message);
  }

  static void handleNotificationRoute(
    BuildContext context,
    RemoteMessage message,
  ) {
    central.NotificationHandler.handleNotificationTap(message);
  }

  static void handleForegroundMessage(
    BuildContext context,
    RemoteMessage message,
  ) {
    central.NotificationHandler.handleForegroundMessage(
      context,
      message,
    );
  }

  static void showInAppBanner(
    BuildContext context,
    RemoteMessage message,
  ) {
    central.NotificationHandler.handleForegroundMessage(
      context,
      message,
    );
  }
}