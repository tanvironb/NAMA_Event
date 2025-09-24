import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class UserProfileRepository {
  final FirestoreService _firestoreService;

  UserProfileRepository(this._firestoreService);

  // Provides a stream of AppUser model for the current user.
  Stream<AppUser?> getUserProfileStream(String uid) {
    return _firestoreService.getUserDocumentStream(uid).map((doc) {
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    });
  }

  // Fetches multiple AppUser models by their UIDs.
  Future<List<AppUser>> getUsersByIds(List<String> uids) async {
    final docs = await _firestoreService.getUserDocumentsByIds(uids);
    return docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  // Updates a user's profile.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestoreService.updateUserDocument(uid, data);
  }
}