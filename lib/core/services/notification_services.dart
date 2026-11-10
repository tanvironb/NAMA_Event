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
  bool _tokenRetryInProgress = false;

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

      final settings = await _firebaseMessaging.requestPermission(
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

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
        debugPrint(
          'NotificationService: Phone notification permission '
          'has not been granted.',
        );
        return;
      }

      await LocalNotificationService.initialize();

      if (!_isCurrentAccount) return;

      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
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
          'but device registration is incomplete. Retrying token setup.',
        );
        unawaited(_retryTokenRegistration());
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
          'NotificationService: Notification tap stream error: $error',
        );
      },
    );

    _onTokenRefreshSub ??=
        _firebaseMessaging.onTokenRefresh.listen(
      (token) {
        unawaited(_saveRefreshedToken(token));
      },
      onError: (Object error) {
        debugPrint(
          'NotificationService: Token refresh stream error: $error',
        );
      },
    );
  }

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 1; attempt <= 15; attempt++) {
      if (!_isCurrentAccount) return null;

      try {
        final token = await _firebaseMessaging.getAPNSToken();

        if (token != null && token.isNotEmpty) {
          debugPrint(
            'NotificationService: APNs token is ready.',
          );
          return token;
        }
      } catch (error) {
        debugPrint(
          'NotificationService: APNs token check $attempt failed: $error',
        );
      }

      if (attempt < 15) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    debugPrint(
      'NotificationService: APNs token is still unavailable '
      'after retries.',
    );
    return null;
  }

  Future<bool> _saveCurrentToken() async {
    if (!_isCurrentAccount) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _waitForApnsToken();

        if (apnsToken == null || !_isCurrentAccount) {
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

      return await _persistToken(token);
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService: Could not get/save FCM token: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _retryTokenRegistration() async {
    if (_tokenRetryInProgress || !_isCurrentAccount) return;

    _tokenRetryInProgress = true;

    try {
      for (var attempt = 1; attempt <= 5; attempt++) {
        await Future.delayed(const Duration(seconds: 3));

        if (!_isCurrentAccount) return;

        debugPrint(
          'NotificationService: Token registration retry $attempt of 5.',
        );

        if (await _saveCurrentToken()) {
          _isInitialized = true;
          debugPrint(
            'NotificationService: FCM token saved on retry.',
          );
          return;
        }
      }

      debugPrint(
        'NotificationService: FCM token registration still failed. '
        'Check device logs and iOS push configuration.',
      );
    } finally {
      _tokenRetryInProgress = false;
    }
  }

  Future<bool> _persistToken(String token) async {
    if (!_isCurrentAccount || token.isEmpty) {
      return false;
    }

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
      if (!_isCurrentAccount || token.isEmpty) return;

      final saved = await _persistToken(token);

      if (saved) {
        _isInitialized = true;
        debugPrint(
          'NotificationService: Refreshed device token saved.',
        );
      }
    } catch (error, stackTrace) {
      _isInitialized = false;

      debugPrint(
        'NotificationService: Failed to save refreshed token: $error',
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