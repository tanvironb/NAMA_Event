import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/services/notification_handler.dart';
import 'package:events_app_trueattempt/features/notifications/widgets/alert_popup_dialog.dart';

/// Handles Firestore alert notifications and enables iOS foreground banners.
class AlertNotificationService {
  static final AlertNotificationService _instance =
      AlertNotificationService._internal();

  factory AlertNotificationService() => _instance;

  AlertNotificationService._internal();

  final Set<String> _shownAlertIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  /// Initialize the service and start listening for alert notifications.
  Future<void> initialize(BuildContext context) async {
    // iOS does not display FCM notifications as banners while the app is
    // in the foreground unless foreground presentation is enabled.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _startListening();

    // Allow the Firestore listener to start before checking existing alerts.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Start listening for unread alert notifications in Firestore.
  void _startListening() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      debugPrint('AlertNotificationService: No user logged in');
      return;
    }

    // Prevent multiple listeners if initialize() is called again.
    _subscription?.cancel();

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: 'alert')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final notification =
                AppNotification.fromFirestore(change.doc);
            unawaited(_handleAlertNotification(notification));
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'AlertNotificationService: Firestore listener error: $error',
        );
      },
    );

    debugPrint('AlertNotificationService: Started listening for alerts');
  }

  /// Handle a Firestore alert by showing its popup.
  Future<void> _handleAlertNotification(
    AppNotification notification,
  ) async {
    if (_shownAlertIds.contains(notification.id)) {
      debugPrint(
        'AlertNotificationService: Alert ${notification.id} already shown',
      );
      return;
    }

    if (!notification.showsPopup) {
      debugPrint(
        'AlertNotificationService: '
        'Notification ${notification.id} is not a popup type',
      );
      return;
    }

    final notificationId =
        notification.data['notificationId'] ?? notification.id;

    final wasDismissed =
        await AlertPopupDialog.hasBeenDismissed(notificationId);

    if (wasDismissed) {
      debugPrint(
        'AlertNotificationService: Alert $notificationId was previously dismissed',
      );
      return;
    }

    debugPrint(
      'AlertNotificationService: Showing alert popup for ${notification.id}',
    );

    _shownAlertIds.add(notification.id);
    _showAlertPopup(notification);
  }

  /// Show the alert popup dialog.
  void _showAlertPopup(AppNotification notification) {
    final context = NotificationHandler.navigatorKey.currentContext;

    if (context == null) {
      debugPrint(
        'AlertNotificationService: No context available to show popup',
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertPopupDialog(
        notification: notification,
        onDismiss: () {
          unawaited(_markAlertAsRead(notification.id));
        },
      ),
    );
  }

  /// Mark an alert notification as read in Firestore.
  Future<void> _markAlertAsRead(String notificationId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      debugPrint(
        'AlertNotificationService: Marked alert $notificationId as read',
      );
    } catch (error) {
      debugPrint(
        'AlertNotificationService: Error marking alert as read: $error',
      );
    }
  }

  /// Check for unread alerts when the app starts.
  Future<void> checkForUnshownAlerts(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      debugPrint(
        'AlertNotificationService: No user logged in for unshown alerts check',
      );
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'alert')
          .where('isRead', isEqualTo: false)
          .get();

      debugPrint(
        'AlertNotificationService: Found ${snapshot.docs.length} unread alerts',
      );

      if (snapshot.docs.isEmpty) return;

      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aValue = a.data()['timestamp'];
          final bValue = b.data()['timestamp'];

          final aTime =
              aValue is Timestamp ? aValue.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              bValue is Timestamp ? bValue.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

          return bTime.compareTo(aTime);
        });

      final notification =
          AppNotification.fromFirestore(sortedDocs.first);

      if (_shownAlertIds.contains(notification.id) ||
          !notification.showsPopup) {
        return;
      }

      final notificationId =
          notification.data['notificationId'] ?? notification.id;

      final wasDismissed =
          await AlertPopupDialog.hasBeenDismissed(notificationId);

      if (!wasDismissed && context.mounted) {
        await _handleAlertNotification(notification);
      }

      if (snapshot.docs.length > 1) {
        debugPrint(
          'AlertNotificationService: '
          '${snapshot.docs.length - 1} more alerts are available in Notifications',
        );
      }
    } catch (error) {
      debugPrint(
        'AlertNotificationService: Error checking for unshown alerts: $error',
      );
    }
  }

  /// Dispose the Firestore listener.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('AlertNotificationService: Disposed');
  }

  /// Clear shown alert IDs.
  Future<void> clearShownAlerts() async {
    _shownAlertIds.clear();
    debugPrint('AlertNotificationService: Cleared shown alerts');
  }
}