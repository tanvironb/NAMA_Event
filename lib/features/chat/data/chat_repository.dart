// lib/features/chat/data/chat_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/services/session_chat_deletion.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
class ChatRepository {
  final FirestoreService _firestoreService;
  ChatRepository(this._firestoreService);
  Future<DocumentReference<Map<String, dynamic>>> _addRoomMessage(
    String eventId, String senderId, Map<String, dynamic> message,
  ) async {
    final db = FirebaseFirestore.instance;
    final room = db.collection('speaker_moderator_rooms').doc(eventId);
    final ref = room.collection('messages').doc();
    await db.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(room);
      final muted = snapshot.data()?['mutedUsers'];
      if (muted is List && muted.contains(senderId)) {
        throw StateError('You have been muted');
      }
      transaction.set(ref, message);
    });
    return ref;
  }

  // ============================================================================
  // SESSION CHAT STREAM
  // ============================================================================
  Stream<List<Message>> getSessionMessagesStream(String sessionId) {
    return _firestoreService.getChatCollectionStream(sessionId).map((snapshot) {
      return snapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>?)?['deletedForEveryone'] != true)
          .map((doc) => Message.fromFirestore(doc)).toList();
    });
  }
  // ============================================================================
  // SPEAKER & MODERATOR ROOM STREAM
  // ============================================================================
  Stream<List<Message>> getSpeakerModeratorRoomMessagesStream(String eventId) {
    return FirebaseFirestore.instance
        .collection('speaker_moderator_rooms')
        .doc(eventId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }
  // ============================================================================
  // SESSION CHAT - SEND TEXT MESSAGE
  // ============================================================================
  Future<void> sendMessage({
    required String sessionId,
    required String text,
    required String senderId,
    required String senderName,
    required String senderImageUrl,
    required String senderRole,
    List<String> mentionedUserIds = const [],
    List<String> mentionedUserNames = const [],
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }
    final messageData = {
      'text': trimmedText,
      'messageType': 'text',
      'fileUrl': '',
      'fileName': '',
      'fileType': '',
      'fileSize': 0,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'senderRole': senderRole,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderId],
      'mentionedUserIds': mentionedUserIds,
      'mentionedUserNames': mentionedUserNames,
      'deletedForEveryone': false,
    };
    await _firestoreService.addChatMessage(sessionId, messageData);
    await _updateSessionAnalytics(sessionId, senderId, senderRole);
  }
  // ============================================================================
  // SESSION CHAT - SEND MATERIAL MESSAGE
  // ============================================================================
  Future<void> sendMaterialMessage({
    required String sessionId,
    required String senderId,
    required String senderName,
    required String senderImageUrl,
    required String senderRole,
    required String fileUrl,
    required String fileName,
    required String fileType,
    required int fileSize,
    String caption = '',
    List<String> mentionedUserIds = const [],
    List<String> mentionedUserNames = const [],
  }) async {
    final messageData = {
      'text': caption.trim(),
      'messageType': fileType == 'image' ? 'image' : 'file',
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'senderRole': senderRole,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderId],
      'mentionedUserIds': mentionedUserIds,
      'mentionedUserNames': mentionedUserNames,
      'deletedForEveryone': false,
    };
    await _firestoreService.addChatMessage(sessionId, messageData);
    await _updateSessionAnalytics(sessionId, senderId, senderRole);
  }
  // ============================================================================
  // SPEAKER & MODERATOR ROOM - SEND TEXT MESSAGE + NOTIFICATIONS
  // ============================================================================
  Future<void> sendSpeakerModeratorRoomMessage({
    required String eventId,
    required String text,
    required String senderId,
    required String senderName,
    required String senderImageUrl,
    required String senderRole,
    List<String> mentionedUserIds = const [],
    List<String> mentionedUserNames = const [],
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }
    final messageRef = await _addRoomMessage(eventId, senderId, {
      'text': trimmedText,
      'messageType': 'text',
      'fileUrl': '',
      'fileName': '',
      'fileType': '',
      'fileSize': 0,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'senderRole': senderRole,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderId],
      'mentionedUserIds': mentionedUserIds,
      'mentionedUserNames': mentionedUserNames,
      'deletedForEveryone': false,
    });
    await _sendSpeakerModeratorRoomNotifications(
      eventId: eventId,
      messageId: messageRef.id,
      senderId: senderId,
      senderName: senderName,
      messageText: trimmedText,
      isMaterialMessage: false,
      mentionedUserIds: mentionedUserIds,
    );
  }
  // ============================================================================
  // SPEAKER & MODERATOR ROOM - SEND MATERIAL MESSAGE + NOTIFICATIONS
  // ============================================================================
  Future<void> sendSpeakerModeratorRoomMaterialMessage({
    required String eventId,
    required String senderId,
    required String senderName,
    required String senderImageUrl,
    required String senderRole,
    required String fileUrl,
    required String fileName,
    required String fileType,
    required int fileSize,
    String caption = '',
    List<String> mentionedUserIds = const [],
    List<String> mentionedUserNames = const [],
  }) async {
    final messageRef = await _addRoomMessage(eventId, senderId, {
      'text': caption.trim(),
      'messageType': fileType == 'image' ? 'image' : 'file',
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'senderRole': senderRole,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderId],
      'mentionedUserIds': mentionedUserIds,
      'mentionedUserNames': mentionedUserNames,
      'deletedForEveryone': false,
    });
    await _sendSpeakerModeratorRoomNotifications(
      eventId: eventId,
      messageId: messageRef.id,
      senderId: senderId,
      senderName: senderName,
      messageText: caption.trim().isEmpty ? fileName : caption.trim(),
      isMaterialMessage: true,
      mentionedUserIds: mentionedUserIds,
    );
  }
  // ============================================================================
  // SPEAKER & MODERATOR ROOM NOTIFICATIONS
  // ============================================================================
  Future<void> _sendSpeakerModeratorRoomNotifications({
    required String eventId,
    required String messageId,
    required String senderId,
    required String senderName,
    required String messageText,
    required bool isMaterialMessage,
    required List<String> mentionedUserIds,
  }) async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final userDoc in usersSnapshot.docs) {
        final receiverId = userDoc.id;
        if (receiverId == senderId) {
          continue;
        }
        final userData = userDoc.data();
        final role = _normalizeRole(
          (userData['role'] ??
                  userData['userRole'] ??
                  userData['userType'] ??
                  userData['type'] ??
                  '')
              .toString(),
        );
        final isSpeakerOrModerator = role == 'speaker' || role == 'moderator';
        if (!isSpeakerOrModerator) {
          continue;
        }
        final eventIds = userData['eventIds'];
        final currentEventId = (userData['currentEventId'] ?? '').toString();
        final activeEventId = (userData['activeEventId'] ?? '').toString();
        bool belongsToEvent = false;
        if (currentEventId == eventId || activeEventId == eventId) {
          belongsToEvent = true;
        }
        if (eventIds is List &&
            eventIds.map((item) => item.toString()).contains(eventId)) {
          belongsToEvent = true;
        }
        if (!belongsToEvent) {
          continue;
        }
        final bool isMentioned = mentionedUserIds.contains(receiverId);
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(receiverId)
            .collection('notifications')
            .doc();
        final String title = isMentioned
            ? 'You were mentioned'
            : 'New message in Speaker Room';
        final String body = isMentioned
            ? '$senderName mentioned you in Speaker & Moderator Room'
            : isMaterialMessage
                ? '$senderName shared a file in Speaker & Moderator Room'
                : '$senderName sent a message in Speaker & Moderator Room';
        batch.set(notificationRef, {
          'eventId': eventId,
          'title': title,
          'subtitle': 'Speaker & Moderator Room',
          'body': body,
          'message': body,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'speakerModeratorRoom',
          'targetRole': role,
          'priority': isMentioned ? 'high' : 'normal',
          'includeDate': true,
          'data': {
            'notificationCategory': isMentioned
                ? 'speakerModeratorRoomMention'
                : 'speakerModeratorRoomMessage',
            'eventId': eventId,
            'roomId': eventId,
            'messageId': messageId,
            'senderId': senderId,
            'senderName': senderName,
            'isMentioned': isMentioned,
            'messagePreview': messageText,
          },
        });
      }
      await batch.commit();
    } catch (e) {
      // Do not block sending messages if notification creation fails.
      // The message itself is already sent.
      // ignore: avoid_print
      print('Failed to create speaker room notifications: $e');
    }
  }
  String _normalizeRole(String role) {
    final cleanRole = role.trim().toLowerCase();
    if (cleanRole == 'speaker_user' ||
        cleanRole == 'speaker user' ||
        cleanRole == 'speaker-user') {
      return 'speaker';
    }
    if (cleanRole == 'moderator_user' ||
        cleanRole == 'moderator user' ||
        cleanRole == 'moderator-user' ||
        cleanRole == 'mod') {
      return 'moderator';
    }
    return cleanRole;
  }
  // ============================================================================
  // DELETE FROM EVERYONE - SPEAKER & MODERATOR ROOM
  // ============================================================================
  Future<void> deleteSpeakerModeratorRoomMessage({
    required String eventId,
    required String messageId,
  }) async {
    await FirebaseFirestore.instance
        .collection('speaker_moderator_rooms')
        .doc(eventId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
  // ============================================================================
  // DELETE FROM EVERYONE - SESSION CHAT
  // ============================================================================
  Future<void> deleteMessage(String sessionId, String messageId) async {
    await deleteSessionChatMessage(
      db: FirebaseFirestore.instance,
      sessionId: sessionId,
      messageId: messageId,
    );
  }
  // ============================================================================
  // SESSION ANALYTICS
  // ============================================================================
  Future<void> _updateSessionAnalytics(
    String sessionId,
    String senderId,
    String senderRole,
  ) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final sessionDoc = await transaction.get(sessionRef);
      if (!sessionDoc.exists) return;
      final data = sessionDoc.data()!;
      final participants = List<String>.from(data['uniqueParticipants'] ?? []);
      final messagesByRole = Map<String, int>.from(data['messagesByRole'] ?? {});
      final isFirstMessage = data['firstMessageAt'] == null;
      if (!participants.contains(senderId)) {
        participants.add(senderId);
      }
      messagesByRole[senderRole] = (messagesByRole[senderRole] ?? 0) + 1;
      final updates = <String, dynamic>{
        'totalMessages': FieldValue.increment(1),
        'uniqueParticipants': participants,
        'messagesByRole': messagesByRole,
        'lastMessageAt': now,
      };
      if (isFirstMessage) {
        updates['firstMessageAt'] = now;
      }
      transaction.update(sessionRef, updates);
    });
  }
  // ============================================================================
  // SESSION CHECK-IN
  // ============================================================================
  Future<void> checkInAttendee(String sessionId, String attendeeId) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    await sessionRef.update({
      'checkedInAttendees': FieldValue.arrayUnion([attendeeId]),
    });
  }
  // ============================================================================
  // SESSION CHAT ENABLE / DISABLE
  // ============================================================================
  Future<void> toggleChatEnabled(
    String sessionId,
    bool enabled,
    String closedByRole,
  ) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    await sessionRef.update({
      'isChatEnabled': enabled,
      'closedBy': enabled ? '' : closedByRole,
    });
  }
  // ============================================================================
  // MUTE / UNMUTE
  // ============================================================================
  Future<void> muteUser(String sessionId, String userId) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    await sessionRef.update({
      'mutedUsers': FieldValue.arrayUnion([userId]),
      'muteHistory': FieldValue.arrayUnion([userId]),
      'totalMuteActions': FieldValue.increment(1),
    });
  }
  Future<void> unmuteUser(String sessionId, String userId) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    await sessionRef.update({
      'mutedUsers': FieldValue.arrayRemove([userId]),
    });
  }
}
