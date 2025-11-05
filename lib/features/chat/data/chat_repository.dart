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
    required String senderRole,
  }) async {
    final messageData = {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'senderRole': senderRole,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderId], // Sender has read their own message
    };
    await _firestoreService.addChatMessage(sessionId, messageData);
    
    // Update session analytics
    await _updateSessionAnalytics(sessionId, senderId);
  }

  Future<void> _updateSessionAnalytics(String sessionId, String senderId) async {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    
    // Use transaction to safely update analytics
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final sessionDoc = await transaction.get(sessionRef);
      
      if (!sessionDoc.exists) return;
      
      final data = sessionDoc.data()!;
      final participants = List<String>.from(data['uniqueParticipants'] ?? []);
      
      // Add sender to unique participants if not already there
      if (!participants.contains(senderId)) {
        participants.add(senderId);
      }
      
      transaction.update(sessionRef, {
        'totalMessages': FieldValue.increment(1),
        'uniqueParticipants': participants,
      });
    });
  }

  /// Check in an attendee to a session (called when QR code is scanned)
  Future<void> checkInAttendee(String sessionId, String attendeeId) async {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    
    await sessionRef.update({
      'checkedInAttendees': FieldValue.arrayUnion([attendeeId]),
    });
  }

  /// Toggle chat availability for a session (speaker/admin only)
  Future<void> toggleChatEnabled(String sessionId, bool enabled) async {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    
    await sessionRef.update({
      'isChatEnabled': enabled,
    });
  }

  Future<void> deleteMessage(String sessionId, String messageId) async {
    await _firestoreService.deleteChatMessage(sessionId, messageId);
  }
}