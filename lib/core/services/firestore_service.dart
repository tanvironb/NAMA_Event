import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService(this._db);

  Future<DocumentSnapshot> getActiveEvent() async {
    final snapshot =
        await _db.collection('events').where('isActive', isEqualTo: true).limit(1).get();
    if (snapshot.docs.isEmpty) {
      throw Exception("No active event found!");
    }
    return snapshot.docs.first;
  }

  Stream<DocumentSnapshot?> getUserProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<QuerySnapshot> getSessionsStream(String eventId) {
    return _db
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .orderBy('startTime')
        .snapshots();
  }
  
  Stream<QuerySnapshot> getSponsorsStream(String eventId) {
    return _db
        .collection('sponsors')
        .where('eventId', isEqualTo: eventId)
        .snapshots();
  }

  Future<List<DocumentSnapshot>> getUsersByIds(List<String> userIds) async {
     if (userIds.isEmpty) return [];
     final snapshot = await _db.collection('users').where(FieldPath.documentId, whereIn: userIds).get();
     return snapshot.docs;
  }
}