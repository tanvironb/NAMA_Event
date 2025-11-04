import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/conversation_model.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class MessagingRepository {
  final FirestoreService _firestoreService;
  MessagingRepository(this._firestoreService);

  Stream<List<Conversation>> getConversationsStream(String userId) {
    return _firestoreService.getConversationsCollectionStream(userId).map((snapshot) {
      return snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Message>> getDirectMessagesStream(String conversationId) {
    return _firestoreService.getDirectMessagesCollectionStream(conversationId).map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  Future<void> sendDirectMessage({
    required String conversationId,
    required String text,
    required String senderId,
    required String senderName,
    required String senderImageUrl,
  }) async {
    final messageData = {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };
    await _firestoreService.addDirectMessage(conversationId, messageData);
  }

  Future<String> createOrGetConversation(String currentUserId, String otherUserId) async {
    return await _firestoreService.createOrGetConversation(currentUserId, otherUserId);
  }

  /// Mark messages as read by adding the user ID to the readBy array
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('directMessages')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId) // Only mark messages not sent by current user
        .get();

    final batch = FirebaseFirestore.instance.batch();
    
    for (final doc in messagesSnapshot.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(userId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }
    }

    // Reset unread count for this user in the conversation
    batch.update(
      FirebaseFirestore.instance.collection('directMessages').doc(conversationId),
      {
        'unreadCount.$userId': 0,
      },
    );

    await batch.commit();
  }
}