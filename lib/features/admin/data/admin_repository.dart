import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class AdminRepository {
  final FirestoreService _firestoreService;
  AdminRepository(this._firestoreService);

  Stream<List<AppUser>> getAllUsersStream() {
    return _firestoreService.getAllUsersStream().map((snapshot) => 
      snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList()
    );
  }
}