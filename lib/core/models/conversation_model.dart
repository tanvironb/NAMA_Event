import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> members;
  final Map<String, dynamic> memberInfo;
  final String lastMessageText;
  final Timestamp lastMessageTimestamp;

  Conversation({
    required this.id,
    required this.members,
    required this.memberInfo,
    this.lastMessageText = '',
    required this.lastMessageTimestamp,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw StateError('Missing data for conversation ${doc.id}');
    
    return Conversation(
      id: doc.id,
      members: List<String>.from(data['members'] ?? []),
      memberInfo: Map<String, dynamic>.from(data['memberInfo'] ?? {}),
      lastMessageText: data['lastMessageText'] as String? ?? '',
      lastMessageTimestamp: data['lastMessageTimestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}