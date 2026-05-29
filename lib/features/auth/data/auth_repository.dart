// lib/features/auth/data/auth_repository.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;

  AuthRepository(this._firebaseAuth, this._firestoreService);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Gets the currently active event ID.
  /// If no active event exists, it returns null and does not block login/register.
  Future<String?> _getActiveEventIdSafely() async {
    try {
      final activeEventDoc = await _firestoreService.getActiveEventDocument();
      return activeEventDoc.id;
    } catch (e) {
      debugPrint('Warning: Failed to get active event ID: $e');
      return null;
    }
  }

  /// Ensures the current user is linked to the active event.
  /// This is important for Networking page filtering.
  Future<void> _attachUserToActiveEvent(String uid) async {
    final activeEventId = await _getActiveEventIdSafely();

    if (activeEventId == null || activeEventId.isEmpty) return;

    await _firestoreService.updateUserDocument(
      uid,
      {
        'eventIds': FieldValue.arrayUnion([activeEventId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final signedInUser = userCredential.user;

    if (signedInUser == null) {
      await _firebaseAuth.signOut();

      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found.',
      );
    }

    /*
      IMPORTANT FIX:
      After email verification, Firebase can still keep the old cached user
      where emailVerified is false.

      So we MUST reload the user first, then read the refreshed user from
      FirebaseAuth.instance.currentUser.
    */
    await signedInUser.reload();

    final refreshedUser = _firebaseAuth.currentUser;

    if (refreshedUser == null) {
      await _firebaseAuth.signOut();

      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found after refresh.',
      );
    }

    if (!refreshedUser.emailVerified) {
      await _firebaseAuth.signOut();

      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Your email is pending verification.',
      );
    }

    final userDoc = await _firestoreService.getUserDocument(refreshedUser.uid);

    if (!userDoc.exists) {
      await _firebaseAuth.signOut();

      throw FirebaseAuthException(
        code: 'user-not-authorized',
        message: 'Account not found. Please register.',
      );
    }

    try {
      await _firestoreService.updateUserDocument(
        refreshedUser.uid,
        {
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        },
      );

      // Automatically connect attendee/user to the active event on login.
      // This makes the user appear in Networking for the active event.
      await _attachUserToActiveEvent(refreshedUser.uid);
    } catch (e) {
      debugPrint('Warning: Failed to update user login data: $e');
    }

    return userCredential;
  }

  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? name,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final activeEventId = await _getActiveEventIdSafely();

      final userData = {
        'email': email.trim(),
        'name': name ?? email.trim().split('@')[0],
        'role': 'attendee',
        'status': 'approved',

        // Automatically connect new attendee to current active event.
        'eventIds': activeEventId != null && activeEventId.isNotEmpty
            ? [activeEventId]
            : [],

        'profileVisibility': 'minimal',
        'qrCodePayload': '',
        'profileImageUrl': '',
        'title': '',
        'company': '',
        'bio': '',
        'phone': '',
        'linkedin': '',
        'twitter': '',
        'website': '',
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestoreService.createUserDocument(
        uid: userCredential.user!.uid,
        userData: userData,
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message:
              'This email is already registered. Please sign in or use password reset if you forgot your password.',
        );
      }

      rethrow;
    }
  }

  Future<void> signOut() async {
    final user = _firebaseAuth.currentUser;

    if (user != null) {
      try {
        await _firestoreService.updateUserDocument(
          user.uid,
          {
            'fcmToken': FieldValue.delete(),
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Warning: Firestore update timed out during sign-out');
          },
        );
      } catch (e) {
        debugPrint(
          'Warning: Failed to update user session data on sign-out: $e',
        );
      }
    }

    await _firebaseAuth.signOut();
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;

    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  User? get currentUser => _firebaseAuth.currentUser;
}

// Riverpod provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreServiceProvider),
  );
});