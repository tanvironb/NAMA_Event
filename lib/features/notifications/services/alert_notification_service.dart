import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/features/notifications/widgets/alert_popup_dialog.dart';

/// Service to handle alert notifications with popup display
/// Listens for high-priority notifications and shows popup with 3-second timer
class AlertNotificationService {
  static final AlertNotificationService _instance = AlertNotificationService._internal();
  factory AlertNotificationService() => _instance;
  AlertNotificationService._internal();

  final Set<String> _shownAlertIds = {};
  StreamSubscription<QuerySnapshot>? _subscription;

  /// Initialize the service and start listening for alerts
  Future<void> initialize(BuildContext context) async {
    _startListening(context);
  }

  /// Start listening for alert notifications
  void _startListening(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('AlertNotificationService: No user logged in');
      return;
    }

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: 'alert')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notification = AppNotification.fromFirestore(change.doc);
          _handleAlertNotification(context, notification);
        }
      }
    });

    debugPrint('AlertNotificationService: Started listening for alerts');
  }

  /// Handle an alert notification by showing popup
  void _handleAlertNotification(BuildContext context, AppNotification notification) {
    // Skip if already shown
    if (_shownAlertIds.contains(notification.id)) {
      debugPrint('AlertNotificationService: Alert ${notification.id} already shown');
      return;
    }

    // Skip if not a popup type
    if (!notification.showsPopup) {
      debugPrint('AlertNotificationService: Notification ${notification.id} is not a popup type');
      return;
    }

    debugPrint('AlertNotificationService: Showing alert popup for ${notification.id}');

    // Mark as shown
    _shownAlertIds.add(notification.id);

    // Show popup dialog
    _showAlertPopup(context, notification);
  }

  /// Show the alert popup dialog
  void _showAlertPopup(BuildContext context, AppNotification notification) {
    // Use root navigator to ensure popup shows even if user is in a nested route
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => AlertPopupDialog(
        notification: notification,
        onDismiss: () {
          // Mark notification as read when dismissed
          _markAlertAsRead(notification.id);
        },
      ),
    );
  }

  /// Mark alert notification as read in Firestore
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

      debugPrint('AlertNotificationService: Marked alert $notificationId as read');
    } catch (e) {
      debugPrint('AlertNotificationService: Error marking alert as read: $e');
    }
  }

  /// Check for unshown alerts on app launch
  Future<void> checkForUnshownAlerts(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('AlertNotificationService: No user logged in for unshown alerts check');
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

      debugPrint('AlertNotificationService: Found ${snapshot.docs.length} unread alerts');

      for (final doc in snapshot.docs) {
        final notification = AppNotification.fromFirestore(doc);
        
        // Only show if not already shown and is a popup type
        if (!_shownAlertIds.contains(notification.id) && notification.showsPopup) {
          // Add small delay between popups if multiple alerts
          await Future.delayed(const Duration(milliseconds: 500));
          if (context.mounted) {
            _handleAlertNotification(context, notification);
          }
        }
      }
    } catch (e) {
      debugPrint('AlertNotificationService: Error checking for unshown alerts: $e');
    }
  }

  /// Dispose the service and clean up resources
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('AlertNotificationService: Disposed');
  }

  /// Clear shown alert IDs (useful for testing)
  Future<void> clearShownAlerts() async {
    _shownAlertIds.clear();
    debugPrint('AlertNotificationService: Cleared shown alerts');
  }
}
