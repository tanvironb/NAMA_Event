// lib/core/models/help_ticket_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class HelpTicket {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String subject;
  final String message;
  final String status;

  // Event information used by both Admin and Staff Help Tickets screens.
  final String eventId;
  final String eventName;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const HelpTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.subject,
    required this.message,
    required this.status,
    this.eventId = '',
    this.eventName = '',
    required this.createdAt,
    this.updatedAt,
  });

  factory HelpTicket.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();

    if (rawData == null) {
      throw StateError('Missing help ticket data for ${doc.id}');
    }

    final data = rawData as Map<String, dynamic>;

    return HelpTicket(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'Unknown User').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      subject: (data['subject'] ?? 'No Subject').toString(),
      message: (data['message'] ?? '').toString(),
      status: (data['status'] ?? TicketStatus.pending).toString(),
      eventId: (data['eventId'] ?? '').toString(),
      eventName: (data['eventName'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: data['updatedAt'] != null
          ? _dateTimeFromValue(data['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'subject': subject,
      'message': message,
      'status': status,
      'eventId': eventId,
      'eventName': eventName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  HelpTicket copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? subject,
    String? message,
    String? status,
    String? eventId,
    String? eventName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return HelpTicket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      status: status ?? this.status,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }
    }

    // Prevent old/incomplete ticket documents from crashing the screen.
    return DateTime.now();
  }
}

class TicketStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String spam = 'spam';
  static const String critical = 'critical';
  static const String processed = 'processed';

  static const List<String> values = [
    pending,
    processing,
    spam,
    critical,
    processed,
  ];

  static String getDisplayName(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case processing:
        return 'Processing';
      case spam:
        return 'Spam';
      case critical:
        return 'Critical';
      case processed:
        return 'Processed';
      default:
        return 'Unknown';
    }
  }
}
