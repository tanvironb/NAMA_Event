// lib/features/auth/data/auth_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;

  AuthRepository(this._firebaseAuth, this._firestoreService);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Gets the currently active event ID.
  ///
  /// If no active event exists, this returns null and does not block
  /// login or registration.
  Future<String?> _getActiveEventIdSafely() async {
    try {
      final activeEventDoc = await _firestoreService.getActiveEventDocument();
      return activeEventDoc.id;
    } catch (e) {
      debugPrint('Warning: Failed to get active event ID: $e');
      return null;
    }
  }

  /// Synchronizes a signed-in user with the currently active event.
  ///
  /// This method:
  /// - links the user to the active event through eventIds
  /// - updates currentEventId and activeEventId for attendee/staff accounts
  /// - creates or updates the event registration document
  /// - refreshes the registration profile details on every login
  ///
  /// Speaker and moderator event assignment is not overwritten because those
  /// roles may be assigned to a specific inactive event by an admin.
  Future<void> _syncUserWithActiveEvent(String uid) async {
    final activeEventId = await _getActiveEventIdSafely();

    if (activeEventId == null || activeEventId.trim().isEmpty) {
      debugPrint(
        'AuthRepository: No active event found for user synchronization.',
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final registrationRef = firestore
        .collection('events')
        .doc(activeEventId)
        .collection('registrations')
        .doc(uid);

    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);

      if (!userSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'user-not-found',
          message: 'User profile does not exist.',
        );
      }

      final userData = userSnapshot.data() ?? <String, dynamic>{};

      final rawRole = (userData['role'] ??
              userData['userRole'] ??
              userData['userType'] ??
              userData['type'] ??
              'attendee')
          .toString()
          .trim()
          .toLowerCase();

      final normalizedRole = _normalizeRole(rawRole);

      final shouldFollowGlobalActiveEvent =
          normalizedRole == 'attendee' || normalizedRole == 'staff';

      final userUpdates = <String, dynamic>{
        'eventIds': FieldValue.arrayUnion([activeEventId]),
        'lastSeen': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (shouldFollowGlobalActiveEvent) {
        userUpdates['currentEventId'] = activeEventId;
        userUpdates['activeEventId'] = activeEventId;
      }

      transaction.set(
        userRef,
        userUpdates,
        SetOptions(merge: true),
      );

      final registrationSnapshot = await transaction.get(registrationRef);

      final registrationData = <String, dynamic>{
        'userId': uid,
        'eventId': activeEventId,
        'name': (userData['name'] ??
                userData['fullName'] ??
                userData['displayName'] ??
                '')
            .toString(),
        'email': (userData['email'] ?? '').toString(),
        'role': normalizedRole,
        'company': (userData['company'] ?? '').toString(),
        'title': (userData['title'] ?? '').toString(),
        'profileImageUrl': (userData['profileImageUrl'] ?? '').toString(),
        'status': 'registered',
        'source': 'app_login',
        'lastJoinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!registrationSnapshot.exists) {
        registrationData.addAll({
          'registeredAt': FieldValue.serverTimestamp(),
          'includedInReport': false,
        });
      }

      transaction.set(
        registrationRef,
        registrationData,
        SetOptions(merge: true),
      );
    });
  }

  String _normalizeRole(String role) {
    final cleanRole = role.trim().toLowerCase();

    if (cleanRole == 'administrator' || cleanRole == 'admins') {
      return 'admin';
    }

    if (cleanRole == 'speaker_user' ||
        cleanRole == 'speaker user' ||
        cleanRole == 'speaker-user') {
      return 'speaker';
    }

    if (cleanRole == 'moderator_user' ||
        cleanRole == 'moderator user' ||
        cleanRole == 'moderator-user' ||
        cleanRole == 'mod') {
      return 'moderator';
    }

    if (cleanRole == 'staff_user' ||
        cleanRole == 'staff user' ||
        cleanRole == 'staff-user') {
      return 'staff';
    }

    if (cleanRole == 'delegate' ||
        cleanRole == 'delegates' ||
        cleanRole == 'user') {
      return 'attendee';
    }

    if (cleanRole.isEmpty) {
      return 'attendee';
    }

    return cleanRole;
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

    // Refresh Firebase Auth so emailVerified is not read from stale cache.
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
      await _syncUserWithActiveEvent(refreshedUser.uid);
    } catch (e) {
      debugPrint(
        'AuthRepository: Failed to synchronize user with active event: $e',
      );

      // Do not block login because of a registration synchronization issue.
      try {
        await _firestoreService.updateUserDocument(
          refreshedUser.uid,
          {
            'lastSeen': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'isOnline': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      } catch (statusError) {
        debugPrint(
          'AuthRepository: Failed to update fallback login status: '
          '$statusError',
        );
      }
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

      final userData = <String, dynamic>{
        'email': email.trim(),
        'name': name?.trim().isNotEmpty == true
            ? name!.trim()
            : email.trim().split('@')[0],
        'role': 'attendee',
        'status': 'approved',
        'eventIds': activeEventId != null && activeEventId.isNotEmpty
            ? [activeEventId]
            : <String>[],
        'currentEventId':
            activeEventId != null && activeEventId.isNotEmpty
                ? activeEventId
                : '',
        'activeEventId':
            activeEventId != null && activeEventId.isNotEmpty
                ? activeEventId
                : '',
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

      try {
        await _syncUserWithActiveEvent(userCredential.user!.uid);
      } catch (e) {
        debugPrint(
          'AuthRepository: Failed to register new user for active event: $e',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message:
              'This email is already registered. Please sign in or use '
              'password reset if you forgot your password.',
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
            'updatedAt': FieldValue.serverTimestamp(),
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

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreServiceProvider),
  );
});
