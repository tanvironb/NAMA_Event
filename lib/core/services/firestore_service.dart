import 'package:cloud_firestore/cloud_firestore.dart';

// This service acts as a centralized access point for all raw Firestore operations.
// It returns DocumentSnapshots or QuerySnapshots, which Repositories will then map to domain models.
class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService(this._db);

  // --- User-related operations ---
  Future<DocumentSnapshot> getUserDocument(String uid) {
    return _db.collection('users').doc(uid).get();
  }

  Stream<DocumentSnapshot> getUserDocumentStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> createUserDocument({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    await _db.collection('users').doc(uid).set(userData);
  }

  Future<void> updateUserDocument(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> deleteUserDocument(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  Future<List<DocumentSnapshot>> getUserDocumentsByIds(
    List<String> uids,
  ) async {
    if (uids.isEmpty) return [];

    const batchSize = 10;
    final List<DocumentSnapshot> allDocs = [];

    for (int i = 0; i < uids.length; i += batchSize) {
      final batch = uids.skip(i).take(batchSize).toList();

      final snapshot = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      allDocs.addAll(snapshot.docs);
    }

    return allDocs;
  }

  Future<List<DocumentSnapshot>> getUsersByRole(String role) async {
    final snapshot =
        await _db.collection('users').where('role', isEqualTo: role).get();

    return snapshot.docs;
  }

  Future<List<DocumentSnapshot>> getUsersByRoleAndEventId({
    required String role,
    required String eventId,
  }) async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: role)
        .where('eventIds', arrayContains: eventId)
        .get();

    return snapshot.docs;
  }

  Future<List<DocumentSnapshot>> searchUsersByName(String query) async {
    final snapshot = await _db
        .collection('users')
        .where('status', isEqualTo: 'approved')
        .limit(100)
        .get();

    final queryLower = query.toLowerCase();

    return snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;

      if (data == null) return false;

      final name = (data['name'] as String? ?? '').toLowerCase();

      return name.contains(queryLower);
    }).toList();
  }

  Future<List<DocumentSnapshot>> getUsersSortedByPoints() async {
    final snapshot = await _db
        .collection('users')
        .orderBy('points', descending: true)
        .limit(20)
        .get();

    return snapshot.docs;
  }

  Stream<QuerySnapshot> getAllUsersStream() {
    return _db.collection('users').snapshots();
  }

  // --- Event-related operations ---
Future<DocumentSnapshot> getActiveEventDocument() async {
  final snapshot = await _db
      .collection('events')
      .where('isActive', isEqualTo: true)
      .get();

  final activeDocs = snapshot.docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;

    final status =
        (data['status'] ?? '').toString().toLowerCase().trim();

    return status != 'archived';
  }).toList();

  if (activeDocs.isEmpty) {
    throw Exception("No active event found!");
  }

  return activeDocs.first;
}

  // --- Event registration operations ---
  Future<void> createOrUpdateEventRegistration({
    required String eventId,
    required String userId,
    required Map<String, dynamic> registrationData,
  }) async {
    await _db
        .collection('events')
        .doc(eventId)
        .collection('registrations')
        .doc(userId)
        .set(registrationData, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getEventRegistrationsStream(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .collection('registrations')
        .orderBy('registeredAt', descending: true)
        .snapshots();
  }

  Future<QuerySnapshot> getEventRegistrations(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .collection('registrations')
        .orderBy('registeredAt', descending: true)
        .get();
  }

  Future<void> markEventRegistrationsIncludedInReport(String eventId) async {
    final snapshot = await _db
        .collection('events')
        .doc(eventId)
        .collection('registrations')
        .get();

    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'includedInReport': true,
        'includedInReportAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // --- Session-related operations ---
  Stream<QuerySnapshot> getSessionsCollectionStream(String eventId) {
    return _db
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .orderBy('startTime')
        .snapshots();
  }

  Future<QuerySnapshot> getSessionsByPartnerId(String partnerId) {
    return _db
        .collection('sessions')
        .where('partnerId', isEqualTo: partnerId)
        .get();
  }

  Future<List<DocumentSnapshot>> getSessionsByIds(
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) return [];

    const batchSize = 10;
    final List<DocumentSnapshot> allDocs = [];

    for (int i = 0; i < sessionIds.length; i += batchSize) {
      final batch = sessionIds.skip(i).take(batchSize).toList();

      final snapshot = await _db
          .collection('sessions')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      allDocs.addAll(snapshot.docs);
    }

    return allDocs;
  }

  Future<void> createCheckinDocument({
    required String sessionId,
    required String userId,
    required Map<String, dynamic> checkinData,
  }) async {
    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('checkins')
        .doc(userId)
        .set(checkinData);
  }

  // --- Session Chat operations ---
  Stream<QuerySnapshot> getChatCollectionStream(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> addChatMessage(
    String sessionId,
    Map<String, dynamic> messageData,
  ) async {
    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('chat')
        .add(messageData);
  }

  Future<void> deleteChatMessage(String sessionId, String messageId) async {
    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('chat')
        .doc(messageId)
        .delete();
  }

  // --- Sponsor-related operations ---
  Stream<QuerySnapshot> getSponsorsCollectionStream(String eventId) {
    return _db
        .collection('sponsors')
        .where('eventId', isEqualTo: eventId)
        .snapshots();
  }

  // --- Notification operations ---
  Stream<QuerySnapshot> getNotificationsCollectionStream({
    required String userId,
    required String eventId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('eventId', isEqualTo: eventId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> createNotificationDocument({
    required String userId,
    required Map<String, dynamic> notificationData,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add(notificationData);
  }

  Future<void> updateNotificationDocument(
    String userId,
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update(data);
  }

  Future<void> deleteNotificationDocument({
    required String userId,
    required String notificationId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  // --- Direct Messaging operations ---
  Stream<QuerySnapshot> getConversationsCollectionStream({
    required String userId,
    required String eventId,
  }) {
    return _db
        .collection('directMessages')
        .where('members', arrayContains: userId)
        .where('eventId', isEqualTo: eventId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getDirectMessagesCollectionStream(
    String conversationId,
  ) {
    return _db
        .collection('directMessages')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> addDirectMessage(
    String conversationId,
    Map<String, dynamic> messageData,
  ) async {
    final conversationRef = _db.collection('directMessages').doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final senderId = messageData['senderId'] as String;
    messageData['readBy'] = [senderId];

    await _db.runTransaction((transaction) async {
      final conversationDoc = await transaction.get(conversationRef);

      if (!conversationDoc.exists) {
        throw Exception('Conversation does not exist.');
      }

      final members =
          List<String>.from(conversationDoc.data()?['members'] ?? []);

      transaction.set(messageRef, messageData);

      final updates = <String, dynamic>{
        'lastMessageText': messageData['text'],
        'lastMessageTimestamp': messageData['timestamp'],
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      for (final memberId in members) {
        if (memberId != senderId) {
          updates['unreadCount.$memberId'] = FieldValue.increment(1);
        }
      }

      transaction.update(conversationRef, updates);
    });
  }

  Future<String> createOrGetConversation({
    required String currentUserId,
    required String otherUserId,
    required String eventId,
  }) async {
    final members = [currentUserId, otherUserId]..sort();

    final safeEventId = eventId.trim();
    final conversationId = '${safeEventId}_${members.join('_')}';

    final conversationRef = _db.collection('directMessages').doc(conversationId);

    final doc = await conversationRef.get();

    if (!doc.exists) {
      final currentUserDoc = await getUserDocument(currentUserId);
      final otherUserDoc = await getUserDocument(otherUserId);

      await conversationRef.set({
        'eventId': safeEventId,
        'members': members,
        'memberInfo': {
          currentUserId: {
            'name': currentUserDoc['name'],
            'profileImageUrl': currentUserDoc['profileImageUrl'],
          },
          otherUserId: {
            'name': otherUserDoc['name'],
            'profileImageUrl': otherUserDoc['profileImageUrl'],
          },
        },
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageText': '',
        'lastMessageSenderId': '',
        'unreadCount': {
          currentUserId: 0,
          otherUserId: 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await conversationRef.update({
        'eventId': safeEventId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return conversationId;
  }

  // --- Meeting operations ---
  Stream<QuerySnapshot> getMeetingsCollectionStream({
    required String userId,
    required String eventId,
  }) {
    return _db
        .collection('meetings')
        .where('memberIds', arrayContains: userId)
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot> getMeetingDocument(
    String meetingId,
  ) async {
    return _db.collection('meetings').doc(meetingId).get();
  }

  Future<void> createMeetingDocument(
    Map<String, dynamic> data,
  ) async {
    await _db.collection('meetings').add(data);
  }

  Future<String> createMeetingDocumentAndReturnId(
    Map<String, dynamic> data,
  ) async {
    final docRef = await _db.collection('meetings').add(data);

    return docRef.id;
  }

  Future<void> updateMeetingDocument(
    String meetingId,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('meetings').doc(meetingId).update(data);
  }
}