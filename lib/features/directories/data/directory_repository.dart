import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class DirectoryRepository {
  final FirestoreService _firestoreService;

  DirectoryRepository(this._firestoreService);

  // Fetches attendees only for the currently active event.
  Future<List<AppUser>> getAttendees(String eventId) async {
    final docs = await _firestoreService.getUsersByRoleAndEventId(
      role: 'attendee',
      eventId: eventId,
    );

    final attendees = docs.map((doc) => AppUser.fromFirestore(doc)).toList();

    attendees.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return attendees;
  }

  // Fetches speakers for the currently active event.
  //
  // Main source:
  // sessions where eventId == activeEvent.id, then collect speakerIds.
  //
  // This is better than only checking users.eventIds because speakers are
  // assigned through sessions.
  Future<List<AppUser>> getSpeakers(String eventId) async {
    final Set<String> speakerIds = {};

    // 1. Get speakers from sessions of the active event.
    final sessionsSnapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .get();

    for (final sessionDoc in sessionsSnapshot.docs) {
      final data = sessionDoc.data();
      final rawSpeakerIds = data['speakerIds'];

      if (rawSpeakerIds is List) {
        for (final id in rawSpeakerIds) {
          final speakerId = id.toString().trim();

          if (speakerId.isNotEmpty) {
            speakerIds.add(speakerId);
          }
        }
      }
    }

    // 2. Also include users directly linked to this event as speaker.
    // This helps if some speakers were created directly in users collection.
    final directSpeakerDocs = await _firestoreService.getUsersByRoleAndEventId(
      role: 'speaker',
      eventId: eventId,
    );

    for (final doc in directSpeakerDocs) {
      speakerIds.add(doc.id);
    }

    if (speakerIds.isEmpty) return [];

    final docs = await _firestoreService.getUserDocumentsByIds(
      speakerIds.toList(),
    );

    final speakers = <AppUser>[];

    for (final doc in docs) {
      try {
        if (doc.exists) {
          speakers.add(AppUser.fromFirestore(doc));
        }
      } catch (_) {
        // Skip broken/incomplete old speaker documents.
      }
    }

    speakers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return speakers;
  }
}