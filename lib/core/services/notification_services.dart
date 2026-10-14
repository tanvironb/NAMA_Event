import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:events_app_trueattempt/features/profile/data/profile_repository.dart';
import 'package:events_app_trueattempt/core/services/local_notification_service.dart';
import 'package:events_app_trueattempt/core/services/notification_handler.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final UserProfileRepository _userProfileRepository;
  final String _userId;

  bool _isInitialized = false;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  NotificationService(this._userProfileRepository, this._userId);

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint(
        'NotificationService: Already initialized, skipping duplicate call.',
      );
      return;
    }

    _isInitialized = true;

    try {
      debugPrint('NotificationService: Starting initialization...');

      debugPrint('NotificationService: Requesting permissions...');

      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        'NotificationService: Permission status: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('NotificationService: Notifications permission denied');
        return;
      }

      await LocalNotificationService.initialize();

      await _setupInteractions();
      await _saveTokenToFirestore();

      debugPrint(
        'NotificationService: Initialization completed successfully',
      );
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Error during initialization: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _saveTokenToFirestore() async {
    try {
      debugPrint('NotificationService: Getting FCM token...');

      final String? fcmToken = await _firebaseMessaging.getToken();

      debugPrint(
        'NotificationService: FCM Token received: ${fcmToken != null ? "Yes" : "No"}',
      );

      if (fcmToken != null && _userId.isNotEmpty) {
        debugPrint('FCM Token: $fcmToken');
        debugPrint('NotificationService: Saving token to user profile...');

        await _userProfileRepository.updateUserProfile(
          _userId,
          {
            'fcmToken': fcmToken,
          },
        );

        debugPrint('NotificationService: Token saved successfully');
      } else {
        debugPrint('NotificationService: Missing FCM token or user ID');
      }

      _firebaseMessaging.onTokenRefresh.listen((String newToken) async {
        try {
          if (_userId.isEmpty) {
            return;
          }

          debugPrint('NotificationService: FCM token refreshed.');

          await _userProfileRepository.updateUserProfile(
            _userId,
            {
              'fcmToken': newToken,
            },
          );

          debugPrint('NotificationService: Refreshed token saved.');
        } catch (error, stackTrace) {
          debugPrint(
            'NotificationService: Error saving refreshed token: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      });
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Error saving FCM token: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _setupInteractions() async {
    try {
      _onMessageSub = FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          debugPrint(
            'Foreground message received: ${message.notification?.title}',
          );
          debugPrint('Message data: ${message.data}');

          /*
            This shows a real phone notification banner when the app is open.

            Android:
            Firebase does not automatically show foreground notification banners.
            So we show it manually using flutter_local_notifications.

            iOS:
            Foreground banner is handled by:
            setForegroundNotificationPresentationOptions().
          */
          await LocalNotificationService.showFromRemoteMessage(message);
        },
      );

      _onMessageOpenedAppSub =
          FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          debugPrint(
            'A new onMessageOpenedApp event was published!',
          );

          NotificationHandler.handleNotificationTap(message);
        },
      );

      final RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();

      if (initialMessage != null) {
        debugPrint('App opened from notification!');

        NotificationHandler.handleNotificationTap(initialMessage);
      }

      debugPrint(
        'NotificationService: Message handlers setup completed',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'NotificationService: Error setting up interactions: $e',
      );
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Cancel stream subscriptions and reset initialization state.
  /// Should be called when the user signs out so a fresh session starts clean.
  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();

    _onMessageSub = null;
    _onMessageOpenedAppSub = null;

    _isInitialized = false;

    debugPrint('NotificationService: Disposed for user $_userId');
  }
}
