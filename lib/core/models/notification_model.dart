import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final Timestamp timestamp;
  final bool isRead;
  // Optional: for deep linking
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.data = const {},
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final docData = doc.data() as Map<String, dynamic>?;
    if (docData == null) {
      throw StateError('Missing data for notification ${doc.id}');
    }
    return AppNotification(
      id: doc.id,
      title: docData['title'] as String,
      body: docData['body'] as String,
      timestamp: docData['timestamp'] as Timestamp,
      isRead: docData['isRead'] as bool? ?? false,
      data: docData['data'] as Map<String, dynamic>? ?? {},
    );
  }
}