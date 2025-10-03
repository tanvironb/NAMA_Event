import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class AgendaRepository {
  final FirestoreService _firestoreService;

  AgendaRepository(this._firestoreService);

  // Provides a stream of Session models for a given event.
  Stream<List<Session>> getSessionsStream(String eventId) {
    return _firestoreService.getSessionsCollectionStream(eventId).map((snapshot) {
      return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
    });
  }

  // Future methods for specific session fetches can be added here if needed
}