import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/features/messaging/screen/direct_message_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
import 'package:events_app_trueattempt/features/meetings/screen/my_meetings_screen.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

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
    final eventId = data['eventId'];

    if (sessionId == null) {
      debugPrint('NotificationHandler: Missing sessionId for feedback notification');
      return;
    }

    debugPrint('NotificationHandler: Navigating to session for feedback: $sessionId');
    
    // Navigate to session chat - it will show the feedback dialog
    _navigateToSession(context, sessionId, eventId ?? '');
  }

  /// Handle session chat notification
  static void _handleSessionChat(BuildContext context, Map<String, dynamic> data) {
    final sessionId = data['sessionId'];
    final eventId = data['eventId'];

    if (sessionId == null) {
      debugPrint('NotificationHandler: Missing sessionId for chat notification');
      return;
    }

    debugPrint('NotificationHandler: Navigating to session chat: $sessionId');
    
    _navigateToSession(context, sessionId, eventId ?? '');
  }

  /// Navigate to session chat screen by fetching session data
  static void _navigateToSession(BuildContext context, String sessionId, String eventId) async {
    try {
      // Show loading
      showInAppBanner(
        context,
        title: 'Loading session...',
        body: 'Please wait',
        showAction: false,
      );

      // Fetch session from Firestore
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        if (context.mounted) {
          showInAppBanner(
            context,
            title: 'Error',
            body: 'Session not found',
            showAction: false,
            backgroundColor: AppColors.errorRed,
          );
        }
        return;
      }

      final session = Session.fromFirestore(sessionDoc);

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionChatScreen(session: session),
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationHandler: Error loading session: $e');
      if (context.mounted) {
        showInAppBanner(
          context,
          title: 'Error',
          body: 'Failed to load session',
          showAction: false,
          backgroundColor: AppColors.errorRed,
        );
      }
    }
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

  /// Handle meeting notification - Navigate to pending tab in My Meetings
  static void _handleMeeting(BuildContext context, Map<String, dynamic> data) {
    final meetingId = data['meetingId'];
    final type = data['type'];
    
    debugPrint('NotificationHandler: Meeting notification received: $meetingId, type: $type');
    
    // Navigate to My Meetings screen with pending tab selected
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MyMeetingsScreen(initialTab: 0), // 0 = Pending tab
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

  /// Show in-app banner for foreground notifications (reusable)
  /// This is the gray popup that appears when notifications arrive in foreground
  static void showInAppBanner(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onTap,
    bool showAction = true,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.namaWhite,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.namaWhite,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        action: showAction && onTap != null
            ? SnackBarAction(
                label: 'View',
                textColor: AppColors.namaGoldenYellow,
                onPressed: onTap,
              )
            : null,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor ?? AppColors.namaDarkGray,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Handle foreground message with in-app banner
  static void handleForegroundMessage(BuildContext context, RemoteMessage message) {
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    final type = message.data['type'];

    debugPrint('NotificationHandler: Foreground message received, type: $type');

    // Show in-app banner with appropriate action
    showInAppBanner(
      context,
      title: title,
      body: body,
      onTap: () => handleNotificationTap(message),
    );
  }
}
