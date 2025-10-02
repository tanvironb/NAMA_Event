import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class CheckinRepository {
  final FirestoreService _firestoreService;

  CheckinRepository(this._firestoreService);

  Future<void> checkInUser({required String sessionId, required String userId}) async {
    final checkinData = {'timestamp': FieldValue.serverTimestamp()};
    await _firestoreService.createCheckinDocument(
      sessionId: sessionId,
      userId: userId,
      checkinData: checkinData,
    );

    // Increment user points for check-in (10 points per check-in)
    await _firestoreService.updateUserDocument(userId, {'points': FieldValue.increment(10)});
  }
}