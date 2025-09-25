import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String senderId;
  final String senderName; // Denormalized for easier display
  final String senderImageUrl; // Denormalized for easier display
  final Timestamp timestamp;

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderImageUrl,
    required this.timestamp,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing data for message ${doc.id}');
    }
    return Message(
      id: doc.id,
      text: data['text'] as String,
      senderId: data['senderId'] as String,
      senderName: data['senderName'] as String? ?? 'User',
      senderImageUrl: data['senderImageUrl'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp,
    );
  }
}