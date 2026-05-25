// lib/core/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';

class AppNotification {
  final String id;
  final String eventId;
  final String eventName;
  final String title;
  final String? subtitle;
  final String body;
  final Timestamp timestamp;
  final DateTime? eventTimestamp;
  final bool includeDate;
  final bool isRead;
  final AppNotificationType type;
  final String targetRole;
  final Map<String, dynamic> data;

  // QR announcement fields
  final String qrPayload;
  final String sessionCode;
  final String sessionTitle;

  AppNotification({
    required this.id,
    this.eventId = '',
    this.eventName = '',
    required this.title,
    this.subtitle,
    required this.body,
    required this.timestamp,
    this.eventTimestamp,
    this.includeDate = true,
    this.isRead = false,
    this.type = AppNotificationType.generic,
    this.targetRole = 'all',
    this.data = const {},
    this.qrPayload = '',
    this.sessionCode = '',
    this.sessionTitle = '',
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final docData = doc.data() as Map<String, dynamic>?;

    if (docData == null) {
      throw StateError('Missing data for notification ${doc.id}');
    }

    AppNotificationType typeFromString(String? typeStr) {
      if (typeStr == null) return AppNotificationType.generic;

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

    final timestampValue = docData['timestamp'];
    final eventTimestampValue = docData['eventTimestamp'];

    final dataMap = docData['data'] is Map<String, dynamic>
        ? docData['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final qrPayload = (docData['qrPayload'] ?? dataMap['qrPayload'] ?? '')
        .toString()
        .trim();

    final sessionCode =
        (docData['sessionCode'] ?? dataMap['sessionCode'] ?? '')
            .toString()
            .trim();

    final sessionTitle =
        (docData['sessionTitle'] ?? dataMap['sessionTitle'] ?? '')
            .toString()
            .trim();

    return AppNotification(
      id: doc.id,
      eventId: docData['eventId'] as String? ?? '',
      eventName: docData['eventName'] as String? ?? '',
      title: docData['title'] as String? ?? '',
      subtitle: docData['subtitle'] as String?,
      body: docData['body'] as String? ?? '',
      timestamp: timestampValue is Timestamp ? timestampValue : Timestamp.now(),
      eventTimestamp:
          eventTimestampValue is Timestamp ? eventTimestampValue.toDate() : null,
      includeDate: docData['includeDate'] as bool? ?? true,
      isRead: docData['isRead'] as bool? ?? false,
      type: typeFromString(docData['type'] as String?),
      targetRole: docData['targetRole'] as String? ?? 'all',
      data: dataMap,
      qrPayload: qrPayload,
      sessionCode: sessionCode,
      sessionTitle: sessionTitle,
    );
  }

  String get priority => type.priority;

  bool get showsPopup => type.showsPopup;

  bool get hasQrData => qrPayload.isNotEmpty || sessionCode.isNotEmpty;
}