// lib/core/services/storage_service.dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile image to Firebase Storage
  /// Works on Web, Android, and iOS
  Future<String> uploadProfileImage(String userId, XFile imageFile) async {
    try {
      final ref = _storage.ref().child('profile/$userId.jpg');

      final bytes = await imageFile.readAsBytes();

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      rethrow;
    }
  }

  Future<void> deleteProfileImage(String userId) async {
    try {
      final ref = _storage.ref().child('profile/$userId.jpg');
      await ref.delete();
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        debugPrint('Profile image not found for user $userId, skipping deletion');
        return;
      }
      debugPrint('Error deleting profile image: $e');
      rethrow;
    }
  }

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