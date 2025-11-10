// lib/core/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile image to Firebase Storage
  /// Returns the download URL of the uploaded image
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      // Create reference to the file location
      final ref = _storage.ref().child('profile/$userId.jpg');
      
      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // Upload the file
      final uploadTask = ref.putFile(imageFile, metadata);
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      rethrow;
    }
  }

  /// Delete profile image from Firebase Storage
  Future<void> deleteProfileImage(String userId) async {
    try {
      final ref = _storage.ref().child('profile/$userId.jpg');
      await ref.delete();
    } catch (e) {
      // If file doesn't exist, that's fine
      if (e is FirebaseException && e.code == 'object-not-found') {
        debugPrint('Profile image not found for user $userId, skipping deletion');
        return;
      }
      debugPrint('Error deleting profile image: $e');
      rethrow;
    }
  }

  /// Get download URL for profile image (if exists)
  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final ref = _storage.ref().child('profile/$userId.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        return null;
      }
      debugPrint('Error getting profile image URL: $e');
      rethrow;
    }
  }

  /// Check if profile image exists
  Future<bool> profileImageExists(String userId) async {
    try {
      final ref = _storage.ref().child('profile/$userId.jpg');
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }
}
