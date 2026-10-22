import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class MerchandiseRepository {
  final FirestoreService _firestoreService;
  MerchandiseRepository(this._firestoreService);

  Stream<QuerySnapshot<Map<String, dynamic>>> merchandiseCollectionStream(String eventId) {
    return FirebaseFirestore.instance.collection('events').doc(eventId)
        .collection('merchandiseCollections')
        .orderBy('collectedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> eventUsersStream(String eventId) {
    return FirebaseFirestore.instance.collection('users')
        .where('eventIds', arrayContains: eventId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCollectionStatus({
    required String eventId,
    required String userId,
  }) {
    return FirebaseFirestore.instance.collection('events').doc(eventId)
        .collection('merchandiseCollections').doc(userId).get();
  }

  Future<void> collectMerchandise({
    required String eventId,
    required AppUser collectedUser,
    required AppUser staffUser,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final collectionRef = firestore.collection('events').doc(eventId)
        .collection('merchandiseCollections').doc(collectedUser.uid);
    final userRef = firestore.collection('users').doc(collectedUser.uid);

    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(collectionRef);
      if (existing.exists) {
        final data = existing.data() ?? <String, dynamic>{};
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'collected') {
          throw Exception('already_collected');
        }
      }

      transaction.set(collectionRef, {
        'eventId': eventId,
        'userId': collectedUser.uid,
        'userName': collectedUser.name,
        'userEmail': collectedUser.email,
        'userRole': collectedUser.role,
        'userProfileImageUrl': collectedUser.profileImageUrl,
        'status': 'collected',
        'collectedBy': staffUser.uid,
        'collectedByName': staffUser.name,
        'collectedByEmail': staffUser.email,
        'collectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(userRef, {
        'merchandiseCollectedEventIds': FieldValue.arrayUnion([eventId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> resetMerchandiseCollection({
    required String eventId,
    required String userId,
  }) async {
    await FirebaseFirestore.instance.collection('events').doc(eventId)
        .collection('merchandiseCollections').doc(userId).delete();
  }
}
