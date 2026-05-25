// lib/features/calendar/data/calendar_repository.dart

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';

class CalendarRepository {
  final FirebaseFirestore _firestore;

  CalendarRepository(this._firestore);

  /// Real-time calendar entries for the active event.
  ///
  /// Role logic:
  /// - attendee/staff: bookmarked active-event sessions + meetings
  /// - speaker/admin: meetings only
  Stream<List<CalendarEntry>> getCalendarEntriesStream({
    required String userId,
    required String eventId,
    required List<String> bookmarkedSessionIds,
    required bool includeSessions,
  }) async* {
    final sessionsStream = includeSessions
        ? _getBookmarkedSessionsStream(
            eventId: eventId,
            sessionIds: bookmarkedSessionIds,
          )
        : Stream<List<Session>>.value([]);

    final meetingsStream = _getMeetingsStream(
      userId: userId,
      eventId: eventId,
    );

    await for (final results in StreamZip([sessionsStream, meetingsStream])) {
      final sessions = results[0] as List<Session>;
      final meetings = results[1] as List<Meeting>;

      final List<CalendarEntry> entries = [];

      for (final session in sessions) {
        final notes = await getEntryNotes(
          userId: userId,
          entryId: session.id,
          entryType: CalendarEntryType.session,
        );

        entries.add(
          CalendarEntry.fromSession(
            session,
            notes: notes,
          ),
        );
      }

      for (final meeting in meetings) {
        final notes = await getEntryNotes(
          userId: userId,
          entryId: meeting.id,
          entryType: CalendarEntryType.meeting,
        );

        entries.add(
          CalendarEntry.fromMeeting(
            meeting,
            notes: notes,
          ),
        );
      }

      entries.sort((a, b) => a.startTime.compareTo(b.startTime));

      yield entries;
    }
  }

  /// One-time calendar entries for the active event.
  ///
  /// Role logic:
  /// - attendee/staff: bookmarked active-event sessions + meetings
  /// - speaker/admin: meetings only
  Future<List<CalendarEntry>> getCalendarEntries({
    required String userId,
    required String eventId,
    required List<String> bookmarkedSessionIds,
    required bool includeSessions,
  }) async {
    final List<CalendarEntry> entries = [];

    if (includeSessions) {
      final sessions = await _getBookmarkedSessions(
        eventId: eventId,
        sessionIds: bookmarkedSessionIds,
      );

      for (final session in sessions) {
        final notes = await getEntryNotes(
          userId: userId,
          entryId: session.id,
          entryType: CalendarEntryType.session,
        );

        entries.add(
          CalendarEntry.fromSession(
            session,
            notes: notes,
          ),
        );
      }
    }

    final meetings = await _getMeetings(
      userId: userId,
      eventId: eventId,
    );

    for (final meeting in meetings) {
      final notes = await getEntryNotes(
        userId: userId,
        entryId: meeting.id,
        entryType: CalendarEntryType.meeting,
      );

      entries.add(
        CalendarEntry.fromMeeting(
          meeting,
          notes: notes,
        ),
      );
    }

    entries.sort((a, b) => a.startTime.compareTo(b.startTime));

    return entries;
  }

  /// Bookmarked sessions from active event only.
  ///
  /// We fetch sessions by eventId first, then filter bookmark IDs locally.
  /// This avoids Firestore whereIn limit issues when user has more than 10 bookmarks.
  Stream<List<Session>> _getBookmarkedSessionsStream({
    required String eventId,
    required List<String> sessionIds,
  }) {
    if (sessionIds.isEmpty) {
      return Stream.value([]);
    }

    final bookmarkedIdsSet = sessionIds.toSet();

    return _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .where((doc) => bookmarkedIdsSet.contains(doc.id))
          .map((doc) => Session.fromFirestore(doc))
          .toList();

      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      return sessions;
    });
  }

  /// Active event meetings only.
  ///
  /// Shows meetings that appear in My Meetings:
  /// - pending
  /// - accepted
  ///
  /// Rejected meetings are excluded from calendar.
  Stream<List<Meeting>> _getMeetingsStream({
    required String userId,
    required String eventId,
  }) {
    return _firestore
        .collection('meetings')
        .where('memberIds', arrayContains: userId)
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final meetings = snapshot.docs
          .map((doc) => Meeting.fromFirestore(doc))
          .where((meeting) {
        return meeting.status == 'pending' || meeting.status == 'accepted';
      }).toList();

      meetings.sort(
        (a, b) => a.proposedTime.toDate().compareTo(b.proposedTime.toDate()),
      );

      return meetings;
    });
  }

  /// Bookmarked sessions from active event only.
  Future<List<Session>> _getBookmarkedSessions({
    required String eventId,
    required List<String> sessionIds,
  }) async {
    if (sessionIds.isEmpty) {
      return [];
    }

    final bookmarkedIdsSet = sessionIds.toSet();

    final snapshot = await _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .get();

    final sessions = snapshot.docs
        .where((doc) => bookmarkedIdsSet.contains(doc.id))
        .map((doc) => Session.fromFirestore(doc))
        .toList();

    sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    return sessions;
  }

  /// Active event meetings only.
  Future<List<Meeting>> _getMeetings({
    required String userId,
    required String eventId,
  }) async {
    final snapshot = await _firestore
        .collection('meetings')
        .where('memberIds', arrayContains: userId)
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .get();

    final meetings = snapshot.docs
        .map((doc) => Meeting.fromFirestore(doc))
        .where((meeting) {
      return meeting.status == 'pending' || meeting.status == 'accepted';
    }).toList();

    meetings.sort(
      (a, b) => a.proposedTime.toDate().compareTo(b.proposedTime.toDate()),
    );

    return meetings;
  }

  /// Save custom notes for a calendar entry.
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

  /// Get custom notes for a calendar entry.
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

    if (!doc.exists) return null;

    return doc.data()?['notes'] as String?;
  }
}