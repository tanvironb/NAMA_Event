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

    // TODO in Phase 3: Increment user points for leaderboard
    // await _firestoreService.updateUserDocument(userId, {'points': FieldValue.increment(10)});
  }
}