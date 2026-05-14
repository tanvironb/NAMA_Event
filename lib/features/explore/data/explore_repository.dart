import 'package:events_app_trueattempt/core/models/event_model.dart';
import 'package:events_app_trueattempt/core/models/sponsor_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventRepository {
  final FirestoreService _firestoreService;

  EventRepository(this._firestoreService);

  Future<Event> getActiveEvent() async {
    final doc = await _firestoreService.getActiveEventDocument();
    return Event.fromFirestore(doc);
  }
}

class SponsorRepository {
  final FirestoreService _firestoreService;

  SponsorRepository(this._firestoreService);

  Stream<List<Sponsor>> getSponsorsStream(String eventId) {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((doc) {
      final data = doc.data();

      if (data == null) return <Sponsor>[];

      final partners = data['partners'];

      if (partners is! List) return <Sponsor>[];

      return partners.asMap().entries.map((entry) {
        final index = entry.key;
        final partner = entry.value;

        if (partner is! Map) {
          return Sponsor(
            id: '${eventId}_partner_$index',
            eventId: eventId,
            name: 'Unnamed Partner',
            logoUrl: '',
          );
        }

        return Sponsor(
          id: '${eventId}_partner_$index',
          eventId: eventId,
          name: (partner['name'] ?? 'Unnamed Partner').toString(),
          logoUrl: (partner['logoUrl'] ?? '').toString(),
          website: (partner['website'] ?? '').toString(),
          description: (partner['description'] ?? '').toString(),
        );
      }).where((sponsor) {
        return sponsor.name.trim().isNotEmpty || sponsor.logoUrl.trim().isNotEmpty;
      }).toList();
    });
  }
}