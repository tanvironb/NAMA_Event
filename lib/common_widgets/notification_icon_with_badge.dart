import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationIconWithBadge extends ConsumerWidget {
  const NotificationIconWithBadge({super.key});

  static const Color titleColor = Color(0xFF0D1496);
  static const Color goldColor = Color(0xFFE2BF3C);

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.now();
  }

  String _notificationReadKey(AppNotification notification) {
    final id = notification.id.trim();

    if (id.isNotEmpty) return id;

    final millis = _toDateTime(notification.timestamp).millisecondsSinceEpoch;

    return '${notification.title}_${notification.subtitle ?? ''}_$millis'
        .replaceAll('/', '_')
        .replaceAll('#', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('.', '_');
  }

  bool _isOldNotification(AppNotification notification) {
    final notificationDate = _toDateTime(notification.timestamp);
    final now = DateTime.now();

    return now.difference(notificationDate).inHours >= 24;
  }

  Stream<Set<String>> _openedNotificationIdsStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream.value(<String>{});
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('readNotifications')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  int _getUnreadCount({
    required List<AppNotification> notifications,
    required Set<String> openedIds,
  }) {
    int count = 0;

    for (final notification in notifications) {
      if (notification.type == AppNotificationType.chat) {
        continue;
      }

      if (_isOldNotification(notification)) {
        continue;
      }

      final readKey = _notificationReadKey(notification);

      if (openedIds.contains(readKey)) {
        continue;
      }

      count++;
    }

    return count;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return StreamBuilder<Set<String>>(
      stream: _openedNotificationIdsStream(),
      builder: (context, readSnapshot) {
        final openedIds = readSnapshot.data ?? <String>{};

        return notificationsAsync.when(
          data: (notifications) {
            final unreadCount = _getUnreadCount(
              notifications: notifications,
              openedIds: openedIds,
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: titleColor,
                  size: 24,
                ),

                if (unreadCount > 0)
                  Positioned(
                    right: -5,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: goldColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () {
            return const Icon(
              Icons.notifications_none_rounded,
              color: titleColor,
              size: 24,
            );
          },
          error: (_, __) {
            return const Icon(
              Icons.notifications_none_rounded,
              color: titleColor,
              size: 24,
            );
          },
        );
      },
    );
  }
}