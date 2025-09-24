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
  
  Future<List<DocumentSnapshot>> getUserDocumentsByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    // Firestore 'whereIn' clause has a limit of 10 items.
    // For larger lists, you'd need to split into multiple queries or use a Cloud Function.
    final snapshot = await _db.collection('users').where(FieldPath.documentId, whereIn: uids).get();
    return snapshot.docs;
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
}