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

 Stream<QuerySnapshot> getChatCollectionStream(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('chat')
        .orderBy('timestamp', descending: true) // Newest messages first
        .snapshots();
  }

  Future<void> addChatMessage(String sessionId, Map<String, dynamic> messageData) async {
    await _db.collection('sessions').doc(sessionId).collection('chat').add(messageData);
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
  
  Future<List<DocumentSnapshot>> getUserDocumentsByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    // Firestore 'whereIn' clause has a limit of 10 items.
    // For larger lists, you'd need to split into multiple queries or use a Cloud Function.
    final snapshot = await _db.collection('users').where(FieldPath.documentId, whereIn: uids).get();
    return snapshot.docs;
  }


  //Fetches users based on their role.
  Future<List<DocumentSnapshot>> getUsersByRole(String role) async {
    final snapshot = await _db.collection('users').where('role', isEqualTo: role).get();
    return snapshot.docs;
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

  // --- Event-related operations ---
  Future<DocumentSnapshot> getActiveEventDocument() async {
    final snapshot =
        await _db.collection('events').where('isActive', isEqualTo: true).limit(1).get();
    if (snapshot.docs.isEmpty) {
      throw Exception("No active event found! Please ensure an event is marked 'isActive: true' in Firestore.");
    }
    return snapshot.docs.first;
  }

  Stream<QuerySnapshot> getNotificationsCollectionStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateNotificationDocument(String userId, String notificationId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).collection('notifications').doc(notificationId).update(data);
  }

  // --- Session-related operations ---
  Stream<QuerySnapshot> getSessionsCollectionStream(String eventId) {
    return _db
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .orderBy('startTime') // Order sessions chronologically
        .snapshots();
  }

  // --- Sponsor-related operations ---
  Stream<QuerySnapshot> getSponsorsCollectionStream(String eventId) {
    return _db
        .collection('sponsors')
        .where('eventId', isEqualTo: eventId)
        .snapshots();
  }

  Stream<QuerySnapshot> getAllUsersStream() {
    return _db.collection('users').snapshots();
  }

  // --- NEW: Direct Messaging operations ---
  Stream<QuerySnapshot> getConversationsCollectionStream(String userId) {
    return _db
        .collection('directMessages')
        .where('members', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getDirectMessagesCollectionStream(String conversationId) {
    return _db
        .collection('directMessages')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> addDirectMessage(String conversationId, Map<String, dynamic> messageData) async {
    final conversationRef = _db.collection('directMessages').doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    await _db.runTransaction((transaction) async {
      transaction.set(messageRef, messageData);
      transaction.update(conversationRef, {
        'lastMessageText': messageData['text'],
        'lastMessageTimestamp': messageData['timestamp'],
      });
    });
  }

  Future<String> createOrGetConversation(String currentUserId, String otherUserId) async {
    final members = [currentUserId, otherUserId]..sort();
    final conversationId = members.join('_');
    final conversationRef = _db.collection('directMessages').doc(conversationId);

    final doc = await conversationRef.get();
    if (!doc.exists) {
      final currentUserDoc = await getUserDocument(currentUserId);
      final otherUserDoc = await getUserDocument(otherUserId);
      
      await conversationRef.set({
        'members': members,
        'memberInfo': {
          currentUserId: {'name': currentUserDoc['name'], 'profileImageUrl': currentUserDoc['profileImageUrl']},
          otherUserId: {'name': otherUserDoc['name'], 'profileImageUrl': otherUserDoc['profileImageUrl']},
        },
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }
    return conversationId;
  }

  Future<List<DocumentSnapshot>> searchUsersByName(String query) async {
    final snapshot = await _db
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();
    return snapshot.docs;
  }

  Future<void> deleteChatMessage(String sessionId, String messageId) async {
    await _db.collection('sessions').doc(sessionId).collection('chat').doc(messageId).delete();
  }
}


