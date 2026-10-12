import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'nama_events_high_importance_channel',
    'NAMA Events Notifications',
    description: 'Important notifications for NAMA Events app.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint(
          'Local notification tapped. Payload: ${response.payload}',
        );
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_androidChannel);

    await androidPlugin?.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _isInitialized = true;
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    await initialize();

    /*
      iOS foreground banner is handled by:
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions()

      If we also show a local notification on iOS, it can show duplicate banners.
      So this local notification is mainly for Android foreground notification.
    */
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return;
    }

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

    final String payload = jsonEncode(message.data);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'NAMA Events',
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails =
        NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}