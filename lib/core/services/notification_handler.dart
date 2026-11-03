import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/direct_message_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notification_detail_screen.dart';

class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _navigationReady = false;
  static RemoteMessage? _pendingMessage;

  static String? get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid;

  static void setNavigationReady(bool ready) {
    _navigationReady = ready;

    if (!ready || _pendingMessage == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_navigationReady ||
          navigatorKey.currentContext == null ||
          _currentUserId == null) {
        return;
      }

      final message = _pendingMessage;
      _pendingMessage = null;

      if (message != null) {
        handleNotificationTap(message);
      }
    });

    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static Map<String, dynamic> _normalize(
    Map<String, dynamic> source,
  ) {
    final result = <String, dynamic>{};
    final nested = source['data'];

    if (nested is Map) {
      result.addAll(Map<String, dynamic>.from(nested));
    } else if (nested is String && nested.isNotEmpty) {
      try {
        final decoded = jsonDecode(nested);

        if (decoded is Map) {
          result.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Continue with the top-level payload.
      }
    }

    result.addAll(source);
    return result;
  }

  static String _text(dynamic value) =>
      value?.toString().trim() ?? '';

  static String _normalizedType(dynamic value) {
    return _text(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), '');
  }

  static void handleNotificationTap(RemoteMessage message) {
    if (!_navigationReady ||
        navigatorKey.currentContext == null ||
        _currentUserId == null) {
      _pendingMessage = message;
      return;
    }

    unawaited(_routeNotification(message));
  }

  static Future<void> _routeNotification(
    RemoteMessage message,
  ) async {
    final context = navigatorKey.currentContext;
    final userId = _currentUserId;

    if (context == null || userId == null) return;

    final data = _normalize(message.data);
    final recipientId = _text(
      data['recipientUid'] ?? data['recipientId'],
    );

    // recipientId is also used as meeting metadata on response
    // notifications, so enforce only the explicit push recipient field.
    final explicitRecipient = _text(data['recipientUid']);

    if (explicitRecipient.isNotEmpty &&
        explicitRecipient != userId) {
      return;
    }

    final senderId = _text(data['senderId']);

    if (senderId.isNotEmpty && senderId == userId) {
      return;
    }

    final type = _normalizedType(data['type']);

    try {
      // Preserve message navigation.
      if (type == 'dm' || type == 'directmessage') {
        _openDirectMessage(context, data);
        return;
      }

      if (type == 'sessionchat' || type == 'sessionfeedback') {
        await _openSession(context, data, userId);
        return;
      }

      final meetingId = _text(data['meetingId']);

      if (meetingId.isNotEmpty || type.startsWith('meeting')) {
        await _openMeetingNotification(
          context,
          data,
          userId,
        );
        return;
      }

      final notificationId = _text(data['notificationId']);

      if (notificationId.isNotEmpty) {
        final document = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId)
            .get();

        if (!context.mounted || _currentUserId != userId) {
          return;
        }

        if (!document.exists) {
          _showError(
            context,
            'This notification is no longer available.',
          );
          return;
        }

        await _openDetails(
          context,
          AppNotification.fromFirestore(document),
        );
        return;
      }

      if (!context.mounted || _currentUserId != userId) {
        return;
      }

      // Fallback only for payloads that do not identify a stored
      // notification or conversation.
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            message.notification?.title ??
                _text(data['title']).ifEmpty('Notification'),
          ),
          content: Text(
            message.notification?.body ??
                _text(data['body'] ?? data['message'])
                    .ifEmpty('You have a new notification.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Notification navigation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (context.mounted && _currentUserId == userId) {
        _showError(
          context,
          'Unable to open this notification. Please try again '
          'from Notifications.',
        );
      }
    }
  }

  static Future<void> _openMeetingNotification(
    BuildContext context,
    Map<String, dynamic> data,
    String userId,
  ) async {
    final notifications = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications');

    final notificationId = _text(data['notificationId']);
    final meetingId = _text(data['meetingId']);

    if (notificationId.isNotEmpty) {
      final document =
          await notifications.doc(notificationId).get();

      if (!context.mounted || _currentUserId != userId) {
        return;
      }

      if (document.exists) {
        await _openDetails(
          context,
          AppNotification.fromFirestore(document),
        );
        return;
      }
    }

    if (meetingId.isEmpty || meetingId.contains('/')) {
      _showError(context, 'Meeting information is missing.');
      return;
    }

    // Existing meeting pushes may contain a meeting ID without
    // the personal notification document ID.
    final snapshot = await notifications
        .where('data.meetingId', isEqualTo: meetingId)
        .get();

    if (!context.mounted || _currentUserId != userId) {
      return;
    }

    if (snapshot.docs.isEmpty) {
      _showError(
        context,
        'This meeting notification is unavailable. '
        'Check My Meetings from your profile.',
      );
      return;
    }

    final documents = snapshot.docs.toList();

    documents.sort((a, b) {
      final aValue = a.data()['timestamp'];
      final bValue = b.data()['timestamp'];

      final aTime =
          aValue is Timestamp ? aValue.millisecondsSinceEpoch : 0;

      final bTime =
          bValue is Timestamp ? bValue.millisecondsSinceEpoch : 0;

      return bTime.compareTo(aTime);
    });

    // Prefer the notification matching the response in the push.
    final requestedStatus = _text(data['status']).toLowerCase();

    DocumentSnapshot<Map<String, dynamic>> selected =
        documents.first;

    if (requestedStatus.isNotEmpty) {
      for (final document in documents) {
        final rawData = document.data()['data'];
        final status = rawData is Map
            ? _text(rawData['status']).toLowerCase()
            : '';

        if (status == requestedStatus) {
          selected = document;
          break;
        }
      }
    }

    await _openDetails(
      context,
      AppNotification.fromFirestore(selected),
    );
  }

  static Future<void> _openDetails(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailScreen(
          notification: notification,
        ),
      ),
    );
  }

  static Future<void> _openSession(
    BuildContext context,
    Map<String, dynamic> data,
    String userId,
  ) async {
    final sessionId = _text(data['sessionId']);

    if (sessionId.isEmpty || sessionId.contains('/')) {
      _showError(context, 'Session information is missing.');
      return;
    }

    final document = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .get();

    if (!context.mounted || _currentUserId != userId) {
      return;
    }

    if (!document.exists) {
      _showError(context, 'This session is no longer available.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionChatScreen(
          session: Session.fromFirestore(document),
        ),
      ),
    );
  }

  static void _openDirectMessage(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final conversationId = _text(data['conversationId']);

    final otherUserId = _text(
      data['otherUserId'] ?? data['senderId'],
    );

    if (conversationId.isEmpty || otherUserId.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ConversationsScreen(),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DirectMessageScreen(
          conversationId: conversationId,
          otherUserId: otherUserId,
          otherUserName:
              _text(data['otherUserName'] ?? data['senderName'])
                  .ifEmpty('User'),
          otherUserProfileImage:
              _text(data['otherUserProfileImage']),
        ),
      ),
    );
  }

  static void _showError(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.namaWhite,
                  ),
                ),
              ],
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
        backgroundColor:
            backgroundColor ?? AppColors.namaDarkGray,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static void handleForegroundMessage(
    BuildContext context,
    RemoteMessage message,
  ) {
    final senderId = _text(message.data['senderId']);

    if (senderId.isNotEmpty && senderId == _currentUserId) {
      return;
    }

    showInAppBanner(
      context,
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      onTap: () => handleNotificationTap(message),
    );
  }
}

extension _NotificationTextFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}