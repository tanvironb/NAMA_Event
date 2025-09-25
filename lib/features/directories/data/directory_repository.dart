// lib/features/directories/data/directory_repository.dart
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class DirectoryRepository {
  final FirestoreService _firestoreService;

  DirectoryRepository(this._firestoreService);

  // Fetches all users with the role 'attendee' who have opted in.
  Future<List<AppUser>> getAttendees() async {
    final docs = await _firestoreService.getUsersByRole('attendee');
    return docs.where((doc) => AppUser.fromFirestore(doc).visibleInDirectory)
               .map((doc) => AppUser.fromFirestore(doc))
               .toList();
  }

  // Fetches all users with the role 'speaker'.
  Future<List<AppUser>> getSpeakers() async {
    final docs = await _firestoreService.getUsersByRole('speaker');
    return docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }
}