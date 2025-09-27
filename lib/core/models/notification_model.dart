// lib/core/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final Timestamp timestamp;
  final bool isRead;
  final AppNotificationType type; // NEW
  final String targetRole; // NEW ('all', 'attendee', 'speaker')
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type = AppNotificationType.generic,
    this.targetRole = 'all',
    this.data = const {},
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final docData = doc.data() as Map<String, dynamic>?;
    if (docData == null) throw StateError('Missing data for notification ${doc.id}');

    // Helper to convert string from Firestore to enum
    AppNotificationType _typeFromString(String? typeStr) {
      return AppNotificationType.values.firstWhere(
        (e) => e.toString() == 'AppNotificationType.$typeStr',
        orElse: () => AppNotificationType.generic,
      );
    }

    return AppNotification(
      id: doc.id,
      title: docData['title'] as String,
      body: docData['body'] as String,
      timestamp: docData['timestamp'] as Timestamp,
      isRead: docData['isRead'] as bool? ?? false,
      type: _typeFromString(docData['type'] as String?),
      targetRole: docData['targetRole'] as String? ?? 'all',
      data: docData['data'] as Map<String, dynamic>? ?? {},
    );
  }
}