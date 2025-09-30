import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class LeaderboardRepository {
  final FirestoreService _firestoreService;
  LeaderboardRepository(this._firestoreService);

  Future<List<AppUser>> getLeaderboardUsers() async {
    final docs = await _firestoreService.getUsersSortedByPoints();
    return docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }
}