import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/profile/data/profile_repository.dart';

// A top-level navigator key is needed to navigate from a background service
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        _handleMessage(message);
      });

      // Handle when a user taps a notification and the app opens from a terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from notification!');
        _handleMessage(initialMessage);
      }
      
      debugPrint('NotificationService: Message handlers setup completed');
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Error setting up interactions: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _showInAppNotification(RemoteMessage message) {
    // Show a snackbar or banner for foreground notifications
    if (navigatorKey.currentContext != null) {
      // TODO: Replace with your actual NotificationHandler when available
      // NotificationHandler.showInAppBanner(navigatorKey.currentContext!, message);
      
      // Temporary simple snackbar implementation
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(message.notification?.body ?? 'New notification'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _handleMessage(message),
          ),
        ),
      );
    }
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint('Handling a tapped notification: ${message.data}');
    final type = message.data['type'];

    // --- DEEP LINKING LOGIC ---
    if (type == 'dm') {
      final conversationId = message.data['conversationId'];
      debugPrint('Navigating to direct message: $conversationId');
      // TODO: Navigate to DirectMessageScreen(conversationId: conversationId)
      // This requires more context (other user's name), which is a good enhancement for later.
      // For now, we can navigate to the main conversations list.
      
      // Uncomment when ConversationsScreen is available:
      // navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const ConversationsScreen()));
      
    } else if (type == 'meeting_request' || type == 'meeting_update') {
      final meetingId = message.data['meetingId'];
      debugPrint('Navigating to meeting: $meetingId');
      // Navigate to the My Meetings screen
      
      // Uncomment when MyMeetingsScreen is available:
      // navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const MyMeetingsScreen()));
      
    } else {
      debugPrint('Unknown notification type: $type');
    }
  }
}