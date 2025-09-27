import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/profile/data/profile_repository.dart';
import 'package:events_app_trueattempt/features/notifications/services/notification_handler.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final UserProfileRepository _userProfileRepository;
  final String _userId;
  static GlobalKey<NavigatorState>? navigatorKey;

  NotificationService(this._userProfileRepository, this._userId);

  Future<void> initialize() async {
    try {
      debugPrint('NotificationService: Starting initialization...');
      
      // Request permission for iOS/web
      debugPrint('NotificationService: Requesting permissions...');
      final NotificationSettings settings = await _firebaseMessaging.requestPermission();
      debugPrint('NotificationService: Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('NotificationService: Notifications permission denied');
        return;
      }

      // Get the FCM token and save it to Firestore
      debugPrint('NotificationService: Getting FCM token...');
      final fcmToken = await _firebaseMessaging.getToken();
      debugPrint('NotificationService: FCM Token received: ${fcmToken != null ? "Yes" : "No"}');
      
      if (fcmToken != null) {
        debugPrint('FCM Token: $fcmToken');
        // Save token to user's profile
        debugPrint('NotificationService: Saving token to user profile...');
        await _userProfileRepository.updateUserProfile(_userId, {'fcmToken': fcmToken});
        debugPrint('NotificationService: Token saved successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Error during initialization: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    // Handle incoming messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        _showInAppNotification(message);
      }
    });

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      _handleNotificationTap(message);
    });

    // Check if app was opened from a notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from notification!');
        _handleNotificationTap(message);
      }
    });
  }

  void _showInAppNotification(RemoteMessage message) {
    // Show a snackbar or banner for foreground notifications
    if (navigatorKey?.currentContext != null) {
      NotificationHandler.showInAppBanner(navigatorKey!.currentContext!, message);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (navigatorKey?.currentContext != null) {
      NotificationHandler.handleNotificationRoute(navigatorKey!.currentContext!, message);
    }
  }
}