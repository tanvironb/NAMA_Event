import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/messaging/screen/direct_message_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';

/// Centralized notification handler for all app notifications
/// Handles deep linking and navigation based on notification type
class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Handle notification tap and navigate to appropriate screen
  static void handleNotificationTap(RemoteMessage message) {
    debugPrint('NotificationHandler: Handling notification tap');
    debugPrint('Notification data: ${message.data}');

    final type = message.data['type'];
    final context = navigatorKey.currentContext;

    if (context == null) {
      debugPrint('NotificationHandler: Navigator context is null');
      return;
    }

    switch (type) {
      case 'session_feedback':
        _handleSessionFeedback(context, message.data);
        break;
      
      case 'session_chat':
        _handleSessionChat(context, message.data);
        break;
      
      case 'dm':
      case 'direct_message':
        _handleDirectMessage(context, message.data);
        break;
      
      case 'meeting_request':
      case 'meeting_update':
        _handleMeeting(context, message.data);
        break;
      
      default:
        debugPrint('NotificationHandler: Unknown notification type: $type');
        _showGenericNotificationDialog(context, message);
    }
  }

  /// Handle session feedback notification
  static void _handleSessionFeedback(BuildContext context, Map<String, dynamic> data) {
    final sessionId = data['sessionId'];

    if (sessionId == null) {
      debugPrint('NotificationHandler: Missing sessionId for feedback notification');
      return;
    }

    debugPrint('NotificationHandler: Navigating to session chat for feedback: $sessionId');
    
    // Navigate to session chat - it will handle showing the feedback dialog
    _navigateToSession(context, sessionId);
  }

  /// Handle session chat notification
  static void _handleSessionChat(BuildContext context, Map<String, dynamic> data) {
    final sessionId = data['sessionId'];

    if (sessionId == null) {
      debugPrint('NotificationHandler: Missing sessionId for chat notification');
      return;
    }

    debugPrint('NotificationHandler: Navigating to session chat: $sessionId');
    
    _navigateToSession(context, sessionId);
  }

  /// Navigate to session chat screen by fetching session data
  static void _navigateToSession(BuildContext context, String sessionId) async {
    // TODO: Fetch session from Firestore and navigate
    // For now, show a message that this requires session data
    debugPrint('NotificationHandler: Session navigation requires Firestore integration');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening session...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Handle direct message notification
  static void _handleDirectMessage(BuildContext context, Map<String, dynamic> data) {
    final conversationId = data['conversationId'];
    final otherUserId = data['otherUserId'];
    final otherUserName = data['otherUserName'];

    if (conversationId == null || otherUserId == null) {
      debugPrint('NotificationHandler: Missing conversationId or otherUserId for DM notification');
      // Navigate to conversations list instead
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ConversationsScreen(),
        ),
      );
      return;
    }

    debugPrint('NotificationHandler: Navigating to direct message: $conversationId');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectMessageScreen(
          conversationId: conversationId,
          otherUserId: otherUserId,
          otherUserName: otherUserName ?? 'User',
          otherUserProfileImage: data['otherUserProfileImage'] ?? '',
        ),
      ),
    );
  }

  /// Handle meeting notification
  static void _handleMeeting(BuildContext context, Map<String, dynamic> data) {
    final meetingId = data['meetingId'];
    
    debugPrint('NotificationHandler: Meeting notification received: $meetingId');
    
    // TODO: Navigate to specific meeting screen when available
    // For now, show a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meeting Notification'),
        content: Text(data['body'] ?? 'You have a meeting notification'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show generic notification dialog for unknown types
  static void _showGenericNotificationDialog(BuildContext context, RemoteMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message.notification?.title ?? 'Notification'),
        content: Text(message.notification?.body ?? 'You have a new notification'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show in-app banner for foreground notifications
  static void showInAppBanner(BuildContext context, RemoteMessage message) {
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';

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
                fontSize: 14,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => handleNotificationTap(message),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
