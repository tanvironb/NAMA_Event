import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class CheckinRepository {
  final FirestoreService _firestoreService;

  CheckinRepository(this._firestoreService);

  Future<void> checkInUser({
    required String sessionId,
    required String userId,
  }) async {
    final checkinData = {
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestoreService.createCheckinDocument(
      sessionId: sessionId,
      userId: userId,
      checkinData: checkinData,
    );

    await _firestoreService.updateUserDocument(
      userId,
      {
        'points': FieldValue.increment(10),
      },
    );
  }

  Future<void> checkInEvent({
    required String eventId,
    required String userId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final eventAttendanceRef = firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .doc(userId);

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

      transaction.update(userRef, {
        'points': FieldValue.increment(10),
      });
    });
  }
}