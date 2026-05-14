import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/conversation_model.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class MessagingRepository {
  final FirestoreService _firestoreService;

  MessagingRepository(this._firestoreService);

  // Loads only conversations for the current active event.
  Stream<List<Conversation>> getConversationsStream({
    required String userId,
    required String eventId,
  }) {
    return _firestoreService
        .getConversationsCollectionStream(
          userId: userId,
          eventId: eventId,
        )
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .toList();
    });
  }

  Stream<List<Message>> getDirectMessagesStream(String conversationId) {
    return _firestoreService
        .getDirectMessagesCollectionStream(conversationId)
        .map((snapshot) {
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

  // Creates or gets a conversation under the current active event.
  Future<String> createOrGetConversation({
    required String currentUserId,
    required String otherUserId,
    required String eventId,
  }) async {
    return await _firestoreService.createOrGetConversation(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
      eventId: eventId,
    );
  }

  /// Mark messages as read by adding the user ID to the readBy array.
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('directMessages')
        .doc(conversationId)
        .collection('messages')
        .where(
          'senderId',
          isNotEqualTo: userId,
        )
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

    batch.update(
      FirebaseFirestore.instance.collection('directMessages').doc(conversationId),
      {
        'unreadCount.$userId': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }
}