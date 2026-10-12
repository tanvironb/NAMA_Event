import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class CheckinRepository {
  // Keep the existing constructor compatible with your providers.
  CheckinRepository(FirestoreService firestoreService);

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  // Regular session self-check-in.
  // The backend blocks self-check-in for breakout sessions.
  Future<void> checkInUser({
    required String sessionId,
    required String userId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw StateError('Sign in to join a session.');
    }

    if (currentUser.uid != userId) {
      throw StateError(
        'Use staff breakout admission to check in another participant.',
      );
    }

    await _functions.httpsCallable('logSessionCheckIn').call({
      'sessionId': sessionId,
    });
  }

  // Staff admission for a breakout session.
  // Staff authorization, participant eligibility, capacity, and duplicate
  // attendance are checked by the backend.
  Future<Map<String, dynamic>> joinBreakoutSession({
    required String sessionId,
    required String userId,
  }) async {
    final result =
        await _functions.httpsCallable('staffJoinBreakoutSession').call({
      'sessionId': sessionId,
      'userId': userId,
    });

    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> checkInEvent({
    required String eventId,
    required String userId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final eventRef = firestore.collection('events').doc(eventId);
    final eventAttendanceRef =
        eventRef.collection('attendance').doc(userId);
    final userRef = firestore.collection('users').doc(userId);

    await firestore.runTransaction((transaction) async {
      final existingAttendance =
          await transaction.get(eventAttendanceRef);
      final userSnapshot = await transaction.get(userRef);

      if (existingAttendance.exists) {
        throw Exception('already_checked_in');
      }

      final userData =
          userSnapshot.data() as Map<String, dynamic>? ?? {};

      final userName = (
        userData['name'] ??
        userData['fullName'] ??
        userData['displayName'] ??
        'Attendee'
      ).toString();

      final userEmail = (userData['email'] ?? '').toString();

      transaction.set(eventAttendanceRef, {
        'eventId': eventId,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedInBy': 'self_scan',
        'qrType': 'event_attendance',
      });

      transaction.update(eventRef, {
        'checkedInAttendees': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(userRef, {
        'points': FieldValue.increment(10),
      });
    });
  }

  Future<void> collectMerchandise({
    required String eventId,
    required AppUser collectedUser,
    required AppUser staffUser,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final collectionRef = firestore
        .collection('events')
        .doc(eventId)
        .collection('merchandiseCollections')
        .doc(collectedUser.uid);

    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(collectionRef);

      if (existing.exists) {
        final existingData =
            existing.data() as Map<String, dynamic>? ?? {};

        if ((existingData['status'] ?? '')
                .toString()
                .toLowerCase() ==
            'collected') {
          throw Exception('already_collected');
        }
      }

      transaction.set(
        collectionRef,
        {
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
        },
        SetOptions(merge: true),
      );
    });
  }
}