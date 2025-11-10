// lib/features/profile/data/profile_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:events_app_trueattempt/core/services/storage_service.dart';

class UserProfileRepository {
  final FirestoreService _firestoreService;
  final StorageService _storageService;

  UserProfileRepository(this._firestoreService, this._storageService);

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

  // Bulk bookmark/unbookmark multiple sessions for a user.
  Future<void> bulkUpdateUserBookmarks(String uid, List<String> sessionIds, bool isBookmarked) async {
    final updateData = {
      'bookmarkedSessions': isBookmarked
          ? FieldValue.arrayUnion(sessionIds)
          : FieldValue.arrayRemove(sessionIds),
    };
    await _firestoreService.updateUserDocument(uid, updateData);
  }

  // Updates user profile with the provided data
  Future<void> updateUserProfile(String uid, Map<String, dynamic> updateData) async {
    await _firestoreService.updateUserDocument(uid, updateData);
  }

  // NEW: Searches for users by name.
  // Note: This is a basic "starts-with" search. For full-text search,
  // can use smth like Algolia for production later.
  Future<List<AppUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    try {
      final snapshot = await _firestoreService.searchUsersByName(query);
      return snapshot.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  // Upload profile image and update user document
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      // Upload to Firebase Storage
      final downloadUrl = await _storageService.uploadProfileImage(userId, imageFile);
      
      // Update Firestore with new URL
      await updateUserProfile(userId, {'profileImageUrl': downloadUrl});
      
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Remove profile image
  Future<void> removeProfileImage(String userId) async {
    try {
      // Delete from Firebase Storage
      await _storageService.deleteProfileImage(userId);
      
      // Update Firestore to remove URL
      await updateUserProfile(userId, {'profileImageUrl': ''});
    } catch (e) {
      rethrow;
    }
  }

  // Update only the profile image URL in Firestore
  Future<void> updateProfileImageUrl(String userId, String imageUrl) async {
    await updateUserProfile(userId, {'profileImageUrl': imageUrl});
  }
}
