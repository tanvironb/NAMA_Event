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
}