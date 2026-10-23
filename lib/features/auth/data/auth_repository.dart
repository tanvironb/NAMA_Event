// lib/features/auth/data/auth_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:events_app_trueattempt/features/auth/data/account_deletion_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;

  final AccountDeletionService _accountDeletionService =
      AccountDeletionService();

  AuthRepository(this._firebaseAuth, this._firestoreService);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

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

    // Refresh Firebase Auth so emailVerified is not read
    // from stale cache.
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
      await _firestoreService.updateUserDocument(refreshedUser.uid, {
        'lastSeen': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (statusError) {
      debugPrint(
        'AuthRepository: Failed to update login status: $statusError',
      );
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

      final userData = <String, dynamic>{
        'email': email.trim(),
        'name':
            name?.trim().isNotEmpty == true
                ? name!.trim()
                : email.trim().split('@')[0],
        'role': 'attendee',
        'status': 'approved',
        // Event membership is added only by the event QR/code join flow.
        // Leaving these fields empty keeps a new account out of event lists
        // and attendance until admission is confirmed by the server.
        'eventIds': <String>[],
        'currentEventId': '',
        'activeEventId': '',
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

      try {
        await _firestoreService.createUserDocument(
          uid: userCredential.user!.uid,
          userData: userData,
        );
      } catch (e) {
        // Do not leave a login without a profile: the user could neither
        // sign in nor register again with the same email.
        try {
          await userCredential.user?.delete();
        } catch (cleanupError) {
          debugPrint(
            'AuthRepository: Failed to remove login after profile error: '
            '$cleanupError',
          );
          await _firebaseAuth.signOut();
        }
        rethrow;
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message:
              'This email address already exists. Please try a different one.',
        );
      }

      rethrow;
    }
  }

  Future<void> signOut() async {
    final user = _firebaseAuth.currentUser;

    if (user != null) {
      try {
        await _firestoreService
            .updateUserDocument(user.uid, {
              'fcmToken': FieldValue.delete(),
              'isOnline': false,
              'lastSeen': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint(
                  'Warning: Firestore update timed out during sign-out',
                );
              },
            );
      } catch (e) {
        debugPrint(
          'Warning: Failed to update user session data '
          'on sign-out: $e',
        );
      }
    }

    // Invalidate this device's push token so the next user on the device
    // does not receive the previous user's notifications.
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('Warning: Failed to delete FCM token on sign-out: $e');
    }

    await _firebaseAuth.signOut();
  }

  /// Reauthenticates the current user and calls the secure
  /// deleteMyAccount Cloud Function.
  ///
  /// The Cloud Function performs all Firestore, Storage,
  /// report-data anonymization, and Firebase Authentication cleanup.
  Future<void> deleteCurrentAccount({required String password}) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user was found.',
      );
    }

    await _accountDeletionService.deleteCurrentAccount(password: password);
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;

    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  User? get currentUser => _firebaseAuth.currentUser;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreServiceProvider),
  );
});
