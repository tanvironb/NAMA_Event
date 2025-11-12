// lib/features/calendar/data/calendar_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';

class CalendarRepository {
  final FirebaseFirestore _firestore;

  CalendarRepository(this._firestore);

  /// Get all calendar entries for a user (bookmarked sessions + approved meetings)
  Stream<List<CalendarEntry>> getCalendarEntries({
    required String userId,
    required String eventId,
    required List<String> bookmarkedSessionIds,
  }) {
    // Combine streams of sessions and meetings
    return _combineStreams(
      userId: userId,
      eventId: eventId,
      bookmarkedSessionIds: bookmarkedSessionIds,
    );
  }

  /// Combine sessions and meetings into a single stream of calendar entries
  Stream<List<CalendarEntry>> _combineStreams({
    required String userId,
    required String eventId,
    required List<String> bookmarkedSessionIds,
  }) async* {
    // Stream bookmarked sessions
    final sessionsStream = _getBookmarkedSessions(eventId, bookmarkedSessionIds);
    
    // Stream approved meetings
    final meetingsStream = _getApprovedMeetings(userId);

    // Combine both streams
    await for (final sessions in sessionsStream) {
      final meetings = await meetingsStream.first;
      
      final List<CalendarEntry> entries = [];
      
      // Add sessions
      entries.addAll(sessions.map((session) => CalendarEntry.fromSession(session)));
      
      // Add meetings
      entries.addAll(meetings.map((meeting) => CalendarEntry.fromMeeting(meeting)));
      
      // Sort by start time
      entries.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      yield entries;
    }
  }

  /// Get bookmarked sessions for the current event
  Stream<List<Session>> _getBookmarkedSessions(String eventId, List<String> sessionIds) {
    if (sessionIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .where(FieldPath.documentId, whereIn: sessionIds)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Session.fromFirestore(doc))
            .toList());
  }

  /// Get approved meetings for the user
  Stream<List<Meeting>> _getApprovedMeetings(String userId) {
    return _firestore
        .collection('meetings')
        .where('memberIds', arrayContains: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Meeting.fromFirestore(doc))
            .toList());
  }

  /// Save custom notes for a calendar entry
  Future<void> saveEntryNotes({
    required String userId,
    required String entryId,
    required CalendarEntryType entryType,
    required String notes,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('calendar_notes')
        .doc('${entryType.name}_$entryId')
        .set({
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get custom notes for a calendar entry
  Future<String?> getEntryNotes({
    required String userId,
    required String entryId,
    required CalendarEntryType entryType,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('calendar_notes')
        .doc('${entryType.name}_$entryId')
        .get();

    if (doc.exists) {
      return doc.data()?['notes'] as String?;
    }
    return null;
  }
}
