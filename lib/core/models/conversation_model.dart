import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final String eventId;
  final List<String> members;
  final Map<String, dynamic> memberInfo;
  final String lastMessageText;
  final Timestamp lastMessageTimestamp;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount;

  Conversation({
    required this.id,
    this.eventId = '',
    required this.members,
    required this.memberInfo,
    this.lastMessageText = '',
    required this.lastMessageTimestamp,
    this.lastMessageSenderId = '',
    Map<String, int>? unreadCount,
  }) : unreadCount = unreadCount ?? {};

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Missing data for conversation ${doc.id}');
    }

    return Conversation(
      id: doc.id,
      eventId: data['eventId'] as String? ?? '',
      members: List<String>.from(data['members'] as List? ?? []),
      memberInfo: Map<String, dynamic>.from(
        data['memberInfo'] as Map? ?? {},
      ),
      lastMessageText: data['lastMessageText'] as String? ?? '',
      lastMessageTimestamp: data['lastMessageTimestamp'] is Timestamp
          ? data['lastMessageTimestamp'] as Timestamp
          : Timestamp.now(),
      lastMessageSenderId: data['lastMessageSenderId'] as String? ?? '',
      unreadCount: _parseUnreadCount(data['unreadCount']),
    );
  }

  static Map<String, int> _parseUnreadCount(dynamic value) {
    if (value is! Map) return {};

    final result = <String, int>{};

    value.forEach((key, val) {
      if (key == null) return;

      if (val is int) {
        result[key.toString()] = val;
      } else if (val is num) {
        result[key.toString()] = val.toInt();
      } else {
        result[key.toString()] = int.tryParse(val.toString()) ?? 0;
      }
    });

    return result;
  }

  int getUnreadCountForUser(String userId) {
    return unreadCount[userId] ?? 0;
  }
}
