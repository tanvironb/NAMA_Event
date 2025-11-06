import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String senderId;
  final String senderName; // Denormalized for easier display
  final String senderImageUrl; // Denormalized for easier display
  final String senderRole; // User role (attendee, speaker, staff, admin) for color coding
  final Timestamp timestamp;
  final List<String> readBy; // List of user IDs who have read this message

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderImageUrl,
    required this.senderRole,
    required this.timestamp,
    List<String>? readBy,
  }) : readBy = readBy ?? [];

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing data for message ${doc.id}');
    }
    
    // Handle null timestamp (serverTimestamp() is null until written)
    final timestampData = data['timestamp'];
    final timestamp = timestampData is Timestamp 
        ? timestampData 
        : Timestamp.now(); // Fallback for pending messages
    
    return Message(
      id: doc.id,
      text: data['text'] as String,
      senderId: data['senderId'] as String,
      senderName: data['senderName'] as String? ?? 'User',
      senderImageUrl: data['senderImageUrl'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? 'attendee',
      timestamp: timestamp,
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }
  
  /// Check if a specific user has read this message
  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }
}