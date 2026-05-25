import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class CheckinRepository {
  final FirestoreService _firestoreService;

  CheckinRepository(this._firestoreService);

  Future<void> checkInUser({
    required String sessionId,
    required String userId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final sessionRef = firestore.collection('sessions').doc(sessionId);
    final checkinRef = sessionRef.collection('checkins').doc(userId);
    final userRef = firestore.collection('users').doc(userId);

    await firestore.runTransaction((transaction) async {
      final sessionSnapshot = await transaction.get(sessionRef);
      final checkinSnapshot = await transaction.get(checkinRef);

      if (!sessionSnapshot.exists) {
        throw Exception('session_not_found');
      }

      final sessionData =
          sessionSnapshot.data() as Map<String, dynamic>? ?? {};

      // If old check-in document already exists, repair checkedInAttendees.
      if (checkinSnapshot.exists) {
        transaction.update(sessionRef, {
          'checkedInAttendees': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return;
      }

      transaction.set(checkinRef, {
        'userId': userId,
        'sessionId': sessionId,
        'eventId': sessionData['eventId'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'checkedInBy': 'self_scan',
        'qrType': 'session_checkin',
      });

      transaction.update(sessionRef, {
        'checkedInAttendees': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(userRef, {
        'points': FieldValue.increment(10),
      });
    });
  }

  Future<void> checkInEvent({
    required String eventId,
    required String userId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final eventRef = firestore.collection('events').doc(eventId);

    final eventAttendanceRef = eventRef.collection('attendance').doc(userId);

    final userRef = firestore.collection('users').doc(userId);

    await firestore.runTransaction((transaction) async {
      final existingAttendance = await transaction.get(eventAttendanceRef);
      final userSnapshot = await transaction.get(userRef);

      if (existingAttendance.exists) {
        throw Exception('already_checked_in');
      }

      final userData = userSnapshot.data() as Map<String, dynamic>? ?? {};

      final userName = (userData['name'] ??
              userData['fullName'] ??
              userData['displayName'] ??
              'Attendee')
          .toString();

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
}