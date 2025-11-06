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
    
    // Update session analytics with role information
    await _updateSessionAnalytics(sessionId, senderId, senderRole);
  }

  Future<void> _updateSessionAnalytics(String sessionId, String senderId, String senderRole) async {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    final now = FieldValue.serverTimestamp();
    
    // Use transaction to safely update analytics
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final sessionDoc = await transaction.get(sessionRef);
      
      if (!sessionDoc.exists) return;
      
      final data = sessionDoc.data()!;
      final participants = List<String>.from(data['uniqueParticipants'] ?? []);
      final messagesByRole = Map<String, int>.from(data['messagesByRole'] ?? {});
      final isFirstMessage = data['firstMessageAt'] == null;
      
      // Add sender to unique participants if not already there
      if (!participants.contains(senderId)) {
        participants.add(senderId);
      }
      
      // Increment role-specific message count
      messagesByRole[senderRole] = (messagesByRole[senderRole] ?? 0) + 1;
      
      // Build update map
      final updates = <String, dynamic>{
        'totalMessages': FieldValue.increment(1),
        'uniqueParticipants': participants,
        'messagesByRole': messagesByRole,
        'lastMessageAt': now,
      };
      
      // Set firstMessageAt only if it's the first message
      if (isFirstMessage) {
        updates['firstMessageAt'] = now;
      }
      
      transaction.update(sessionRef, updates);
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
  /// closedByRole: 'speaker' or 'admin' to track who closed it
  Future<void> toggleChatEnabled(String sessionId, bool enabled, String closedByRole) async {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    
    await sessionRef.update({
      'isChatEnabled': enabled,
      'closedBy': enabled ? '' : closedByRole, // Clear closedBy when reopening
    });
  }

  /// Mute a user in a specific session (speaker/admin only)
  Future<void> muteUser(String sessionId, String userId) async {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    
    await sessionRef.update({
      'mutedUsers': FieldValue.arrayUnion([userId]),
      'muteHistory': FieldValue.arrayUnion([userId]), // Track for analytics
      'totalMuteActions': FieldValue.increment(1),
    });
  }

  /// Unmute a user in a specific session (speaker/admin only)
  Future<void> unmuteUser(String sessionId, String userId) async {
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    
    await sessionRef.update({
      'mutedUsers': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> deleteMessage(String sessionId, String messageId) async {
    await _firestoreService.deleteChatMessage(sessionId, messageId);
    
    // Track deleted message in analytics
    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    await sessionRef.update({
      'deletedMessagesCount': FieldValue.increment(1),
    });
  }
}