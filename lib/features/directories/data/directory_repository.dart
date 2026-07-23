import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class DirectoryRepository {
  final FirestoreService _firestoreService;

  DirectoryRepository(this._firestoreService);

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

  /// Returns both speakers and moderators for the selected event.
  ///
  /// Sources:
  /// - speakerIds and moderatorIds assigned to event sessions
  /// - users linked directly to the event with speaker/moderator role
  Future<List<AppUser>> getSpeakers(String eventId) async {
    final Set<String> userIds = {};

    final sessionsSnapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .get();

    for (final sessionDoc in sessionsSnapshot.docs) {
      final data = sessionDoc.data();

      final rawSpeakerIds = data['speakerIds'];
      if (rawSpeakerIds is List) {
        for (final id in rawSpeakerIds) {
          final cleanId = id.toString().trim();
          if (cleanId.isNotEmpty) userIds.add(cleanId);
        }
      }

      final rawModeratorIds = data['moderatorIds'];
      if (rawModeratorIds is List) {
        for (final id in rawModeratorIds) {
          final cleanId = id.toString().trim();
          if (cleanId.isNotEmpty) userIds.add(cleanId);
        }
      }
    }

    final directSpeakerDocs = await _firestoreService.getUsersByRoleAndEventId(
      role: 'speaker',
      eventId: eventId,
    );

    final directModeratorDocs =
        await _firestoreService.getUsersByRoleAndEventId(
      role: 'moderator',
      eventId: eventId,
    );

    for (final doc in directSpeakerDocs) {
      userIds.add(doc.id);
    }

    for (final doc in directModeratorDocs) {
      userIds.add(doc.id);
    }

    if (userIds.isEmpty) return [];

    final docs = await _firestoreService.getUserDocumentsByIds(
      userIds.toList(),
    );

    final users = <AppUser>[];

    for (final doc in docs) {
      try {
        if (doc.exists) {
          users.add(AppUser.fromFirestore(doc));
        }
      } catch (_) {
        // Skip incomplete legacy documents.
      }
    }

    users.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return users;
  }
}
