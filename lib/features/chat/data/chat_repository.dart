// lib/features/chat/data/chat_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class ChatRepository {
  final FirestoreService _firestoreService;

  ChatRepository(this._firestoreService);

  Stream<List<Message>> getSessionMessagesStream(String sessionId) {
    return _firestoreService.getChatCollectionStream(sessionId).map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  Future<void> sendMessage({
    required String sessionId,
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
    await _firestoreService.addChatMessage(sessionId, messageData);
  }

  Future<void> deleteMessage(String sessionId, String messageId) async {
    await _firestoreService.deleteChatMessage(sessionId, messageId);
  }
}