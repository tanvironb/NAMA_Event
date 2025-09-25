// lib/features/profile/data/profile_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class UserProfileRepository {
  final FirestoreService _firestoreService;

  UserProfileRepository(this._firestoreService);

  // Gets a stream of user profile data for the given user ID
  Stream<AppUser?> getUserProfileStream(String uid) {
    try {
      return _firestoreService.getUserDocumentStream(uid)
          .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
    } catch (e) {
      return Stream.value(null);
    }
  }

  // Gets user profiles by their IDs (for speakers, etc.)
  Future<List<AppUser>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    try {
      final docs = await _firestoreService.getUserDocumentsByIds(userIds);
      return docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  // Gets a single user profile
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _firestoreService.getUserDocument(uid);
      return doc.exists ? AppUser.fromFirestore(doc) : null;
    } catch (e) {
      return null;
    }
  }

  // Updates the bookmarked sessions for a user.
  Future<void> updateUserBookmarks(String uid, String sessionId, bool isBookmarked) async {
    final updateData = {
      'bookmarkedSessions': isBookmarked
          ? FieldValue.arrayUnion([sessionId])
          : FieldValue.arrayRemove([sessionId]),
    };
    await _firestoreService.updateUserDocument(uid, updateData);
  }
}