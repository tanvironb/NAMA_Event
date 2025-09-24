import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/event_model.dart';
import 'package:events_app_trueattempt/core/models/sponsor_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class EventRepository {
  final FirestoreService _firestoreService;

  EventRepository(this._firestoreService);

  // Fetches the single active event.
  Future<Event> getActiveEvent() async {
    final doc = await _firestoreService.getActiveEventDocument();
    return Event.fromFirestore(doc);
  }
  
  // Future methods for other event-related fetches can be added here
}

class SponsorRepository {
  final FirestoreService _firestoreService;

  SponsorRepository(this._firestoreService);

  // Provides a stream of Sponsor models for a given event.
  Stream<List<Sponsor>> getSponsorsStream(String eventId) {
    return _firestoreService.getSponsorsCollectionStream(eventId).map((snapshot) {
      return snapshot.docs.map((doc) => Sponsor.fromFirestore(doc)).toList();
    });
  }

  // Future methods for specific sponsor fetches can be added here
}