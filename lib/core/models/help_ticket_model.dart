import 'package:cloud_firestore/cloud_firestore.dart';

class HelpTicket {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String subject;
  final String message;
  final String status; // 'pending', 'processing', 'spam', 'critical', 'processed'
  final DateTime createdAt;
  final DateTime? updatedAt;

  HelpTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory HelpTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HelpTicket(
      id: doc.id,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      userEmail: data['userEmail'] as String,
      subject: data['subject'] as String,
      message: data['message'] as String,
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

class TicketStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String spam = 'spam';
  static const String critical = 'critical';
  static const String processed = 'processed';

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
