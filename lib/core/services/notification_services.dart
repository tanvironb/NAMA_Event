import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/profile/data/profile_repository.dart';
import 'package:events_app_trueattempt/core/services/notification_handler.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final UserProfileRepository _userProfileRepository;
  final String _userId;

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

      await _saveTokenToFirestore();
      await _setupInteractions();
      
      debugPrint('NotificationService: Initialization completed successfully');
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Error during initialization: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _saveTokenToFirestore() async {
    try {
      debugPrint('NotificationService: Getting FCM token...');
      final fcmToken = await _firebaseMessaging.getToken();

      debugPrint('NotificationService: FCM Token received: ${fcmToken != null ? "Yes" : "No"}');
      
      if (fcmToken != null && _userId.isNotEmpty) {
        debugPrint('FCM Token: $fcmToken');
        debugPrint('NotificationService: Saving token to user profile...');
        await _userProfileRepository.updateUserProfile(_userId, {'fcmToken': fcmToken});
        debugPrint('NotificationService: Token saved successfully');
      } else {
        debugPrint('NotificationService: Missing FCM token or user ID');
      }
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Error saving FCM token: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _setupInteractions() async {
    try {
      // Handle messages received while the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message received: ${message.notification?.title}');
        debugPrint('Message data: ${message.data}');
        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          _showInAppNotification(message);
        }
      });

      // Handle when a user taps a notification and the app opens from the background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        NotificationHandler.handleNotificationTap(message);
      });

      // Handle when a user taps a notification and the app opens from a terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from notification!');
        // Delay slightly to ensure context is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          NotificationHandler.handleNotificationTap(initialMessage);
        });
      }
      
      debugPrint('NotificationService: Message handlers setup completed');
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Error setting up interactions: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _showInAppNotification(RemoteMessage message) {
    // Show a banner for foreground notifications using the reusable handler
    final context = NotificationHandler.navigatorKey.currentContext;
    if (context != null) {
      NotificationHandler.handleForegroundMessage(context, message);
    }
  }
}