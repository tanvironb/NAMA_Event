// lib/core/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';

class AppNotification {
  final String id;
  final String title;
  final String? subtitle; // NEW: Optional side note/mini title
  final String body;
  final Timestamp timestamp;
  final DateTime? timeFrom; // NEW: Optional start time for events
  final DateTime? timeTo; // NEW: Optional end time for events
  final bool isRead;
  final AppNotificationType type;
  final String targetRole; // ('all', 'attendee', 'speaker', 'staff', 'admin')
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.title,
    this.subtitle,
    required this.body,
    required this.timestamp,
    this.timeFrom,
    this.timeTo,
    this.isRead = false,
    this.type = AppNotificationType.generic,
    this.targetRole = 'all',
    this.data = const {},
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final docData = doc.data() as Map<String, dynamic>?;
    if (docData == null) throw StateError('Missing data for notification ${doc.id}');

    // Helper to convert string from Firestore to enum with backward compatibility
    AppNotificationType _typeFromString(String? typeStr) {
      if (typeStr == null) return AppNotificationType.generic;
      
      // Map legacy types to new types for backward compatibility
      final typeMapping = {
        'warning': 'alert',
        'important': 'announcement',
        'reminder': 'information',
      };
      
      final mappedType = typeMapping[typeStr] ?? typeStr;
      
      return AppNotificationType.values.firstWhere(
        (e) => e.toString() == 'AppNotificationType.$mappedType',
        orElse: () => AppNotificationType.generic,
      );
    }

    return AppNotification(
      id: doc.id,
      title: docData['title'] as String,
      subtitle: docData['subtitle'] as String?,
      body: docData['body'] as String,
      timestamp: docData['timestamp'] as Timestamp,
      timeFrom: (docData['timeFrom'] as Timestamp?)?.toDate(),
      timeTo: (docData['timeTo'] as Timestamp?)?.toDate(),
      isRead: docData['isRead'] as bool? ?? false,
      type: _typeFromString(docData['type'] as String?),
      targetRole: docData['targetRole'] as String? ?? 'all',
      data: docData['data'] as Map<String, dynamic>? ?? {},
    );
  }
  
  /// Get priority from type
  String get priority => type.priority;
  
  /// Check if shows popup
  bool get showsPopup => type.showsPopup;
}