import 'package:cloud_firestore/cloud_firestore.dart';

// This service acts as a centralized access point for all Firestore operations.
// It abstracts away the direct Firestore calls from the UI/business logic.
class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService(this._db);

  /// Fetches the single active event from Firestore.
  /// Throws an exception if no active event is found.
  Future<DocumentSnapshot> getActiveEvent() async {
    final snapshot =
        await _db.collection('events').where('isActive', isEqualTo: true).limit(1).get();
    if (snapshot.docs.isEmpty) {
      throw Exception("No active event found! Please ensure an event is marked 'isActive: true' in Firestore.");
    }
    return snapshot.docs.first;
  }

  /// Provides a real-time stream of a user's profile document.
  Stream<DocumentSnapshot?> getUserProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  /// Provides a real-time stream of sessions for a given event, ordered by start time.
  Stream<QuerySnapshot> getSessionsStream(String eventId) {
    return _db
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .orderBy('startTime') // Order sessions chronologically
        .snapshots();
  }
  
  /// Provides a real-time stream of sponsors for a given event.
  Stream<QuerySnapshot> getSponsorsStream(String eventId) {
    return _db
        .collection('sponsors')
        .where('eventId', isEqualTo: eventId)
        .snapshots();
  }

  /// Fetches multiple user documents by their UIDs.
  /// Used to get details for speakers from their IDs listed in sessions.
  Future<List<DocumentSnapshot>> getUsersByIds(List<String> userIds) async {
     if (userIds.isEmpty) return [];
     // Firestore 'whereIn' clause has a limit of 10 items.
     // For larger lists, you'd need to split into multiple queries.
     final snapshot = await _db.collection('users').where(FieldPath.documentId, whereIn: userIds).get();
     return snapshot.docs;
  }

  /// Creates a new user profile document in Firestore.
  Future<void> createUserProfile({
    required String uid,
    required String email,
    String name = 'New User',
    String role = 'attendee',
  }) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'name': name,
      'role': role,
      'profileImageUrl': '',
      'company': '',
      'title': '',
      'bio': '',
      'visibleInDirectory': true,
      'bookmarkedSessions': [],
      'points': 0, // For Phase 3 Leaderboard
      'notificationsEnabled': true, // For Phase 2 Push Notifications
    });
  }
}