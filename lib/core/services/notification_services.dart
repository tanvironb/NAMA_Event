import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:events_app_trueattempt/core/services/local_notification_service.dart';
import 'package:events_app_trueattempt/core/services/notification_handler.dart';
import 'package:events_app_trueattempt/features/profile/data/profile_repository.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  final UserProfileRepository _userProfileRepository;
  final String _userId;

  bool _isInitialized = false;
  bool _disposed = false;

  Future<void>? _initialization;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  NotificationService(
    this._userProfileRepository,
    this._userId,
  );

  bool get _supportsMobileNotifications {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  bool get _isCurrentAccount {
    return !_disposed &&
        _userId.isNotEmpty &&
        FirebaseAuth.instance.currentUser?.uid == _userId;
  }

  Future<void> initialize() async {
    if (_disposed || !_supportsMobileNotifications) {
      return;
    }

    if (!_isCurrentAccount) {
      debugPrint(
        'NotificationService: Initialization skipped because '
        'the signed-in account does not match.',
      );
      return;
    }

    if (_isInitialized) {
      return;
    }

    final pending = _initialization;

    if (pending != null) {
      await pending;
      return;
    }

    final operation = _initialize();
    _initialization = operation;

    try {
      await operation;
    } finally {
      if (identical(_initialization, operation)) {
        _initialization = null;
      }
    }
  }

  Future<void> _initialize() async {
    try {
      debugPrint(
        'NotificationService: Starting setup for user $_userId.',
      );

      final settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (!_isCurrentAccount) return;

      debugPrint(
        'NotificationService: Permission status: '
        '${settings.authorizationStatus.name}',
      );

      if (settings.authorizationStatus ==
              AuthorizationStatus.denied ||
          settings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
        debugPrint(
          'NotificationService: Phone notification permission '
          'has not been granted.',
        );

        // Leave initialization incomplete so it can be retried.
        return;
      }

      await LocalNotificationService.initialize();

      if (!_isCurrentAccount) return;

      // iOS displays foreground notification payloads through FCM.
      // Android uses LocalNotificationService below.
      await _firebaseMessaging
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!_isCurrentAccount) return;

      _attachListeners();

      final tokenSaved = await _saveCurrentToken();

      if (!_isCurrentAccount) return;

      final initialMessage =
          await _firebaseMessaging.getInitialMessage();

      if (!_isCurrentAccount) return;

      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _isInitialized = tokenSaved;

      if (tokenSaved) {
        debugPrint(
          'NotificationService: Setup complete. '
          'Device token saved and message listeners attached.',
        );
      } else {
        debugPrint(
          'NotificationService: Message listeners attached, '
          'but device registration is incomplete. '
          'Initialization can be retried.',
        );
      }
    } catch (error, stackTrace) {
      _isInitialized = false;

      debugPrint(
        'NotificationService: Setup failed: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _attachListeners() {
    _onMessageSub ??= FirebaseMessaging.onMessage.listen(
      (message) {
        // Catch asynchronous callback failures explicitly.
        unawaited(_showForegroundNotification(message));
      },
      onError: (Object error) {
        debugPrint(
          'NotificationService: Foreground stream error: $error',
        );
      },
    );

    _onMessageOpenedAppSub ??=
        FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
      onError: (Object error) {
        debugPrint(
          'NotificationService: Notification tap stream error: '
          '$error',
        );
      },
    );

    _onTokenRefreshSub ??=
        _firebaseMessaging.onTokenRefresh.listen(
      (token) {
        unawaited(_saveRefreshedToken(token));
      },
      onError: (Object error) {
        _isInitialized = false;

        debugPrint(
          'NotificationService: Token refresh stream error: '
          '$error',
        );
      },
    );
  }

  Future<bool> _saveCurrentToken() async {
    if (!_isCurrentAccount) return false;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken =
          await _firebaseMessaging.getAPNSToken();

      if (!_isCurrentAccount) return false;

      if (apnsToken == null || apnsToken.isEmpty) {
        debugPrint(
          'NotificationService: Apple push token is not ready. '
          'Waiting for token refresh or another initialization.',
        );
        return false;
      }
    }

    final token = await _firebaseMessaging.getToken();

    if (!_isCurrentAccount) return false;

    if (token == null || token.isEmpty) {
      debugPrint(
        'NotificationService: Firebase returned no device token.',
      );
      return false;
    }

    return _persistToken(token);
  }

  Future<bool> _persistToken(String token) async {
    if (!_isCurrentAccount || token.isEmpty) {
      return false;
    }

    // Preserve the existing token field used by NAMA Events.
    await _userProfileRepository.updateUserProfile(
      _userId,
      {
        'fcmToken': token,
      },
    );

    if (!_isCurrentAccount) return false;

    debugPrint(
      'NotificationService: Device token saved successfully '
      'for user $_userId.',
    );

    return true;
  }

  Future<void> _saveRefreshedToken(String token) async {
    try {
      if (!_isCurrentAccount) return;

      final saved = await _persistToken(token);

      if (saved) {
        debugPrint(
          'NotificationService: Refreshed device token saved.',
        );
      }
    } catch (error, stackTrace) {
      _isInitialized = false;

      debugPrint(
        'NotificationService: Failed to save refreshed token: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _showForegroundNotification(
    RemoteMessage message,
  ) async {
    if (!_isCurrentAccount) return;

    try {
      debugPrint(
        'NotificationService: Foreground push received. '
        'ID: ${message.messageId ?? "unavailable"}, '
        'type: ${message.data['type'] ?? "unspecified"}.',
      );

      // Android: show the phone notification through the
      // existing local notification service.
      //
      // iOS: the existing local service skips local display,
      // allowing Firebase foreground presentation to display it.
      await LocalNotificationService.showFromRemoteMessage(
        message,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService: Unable to display '
        'foreground notification: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (!_isCurrentAccount) return;

    try {
      NotificationHandler.handleNotificationTap(message);
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService: Notification tap failed: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _isInitialized = false;

    final messageSubscription = _onMessageSub;
    final openedSubscription = _onMessageOpenedAppSub;
    final tokenSubscription = _onTokenRefreshSub;

    _onMessageSub = null;
    _onMessageOpenedAppSub = null;
    _onTokenRefreshSub = null;

    if (messageSubscription != null) {
      unawaited(messageSubscription.cancel());
    }

    if (openedSubscription != null) {
      unawaited(openedSubscription.cancel());
    }

    if (tokenSubscription != null) {
      unawaited(tokenSubscription.cancel());
    }

    debugPrint(
      'NotificationService: Disposed for user $_userId.',
    );
  }
}