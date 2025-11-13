// lib/features/calendar/data/calendar_repository.dart

import 'dart:async';
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';

class CalendarRepository {
  final FirebaseFirestore _firestore;

  CalendarRepository(this._firestore);

  /// Get real-time stream of calendar entries for a user (bookmarked sessions + approved meetings)
  Stream<List<CalendarEntry>> getCalendarEntriesStream({
    required String userId,
    required String eventId,
    required List<String> bookmarkedSessionIds,
  }) async* {
    // Combine both streams (sessions and meetings) and merge them
    final sessionsStream = _getBookmarkedSessionsStream(eventId, bookmarkedSessionIds);
    final meetingsStream = _getApprovedMeetingsStream(userId);
    
    await for (final results in StreamZip([sessionsStream, meetingsStream])) {
      final sessions = results[0] as List<Session>;
      final meetings = results[1] as List<Meeting>;
      
      final List<CalendarEntry> entries = [];
      
      // Convert sessions to calendar entries WITH notes
      for (final session in sessions) {
        final notes = await getEntryNotes(
          userId: userId,
          entryId: session.id,
          entryType: CalendarEntryType.session,
        );
        entries.add(CalendarEntry.fromSession(session, notes: notes));
      }
      
      // Convert meetings to calendar entries WITH notes
      for (final meeting in meetings) {
        final notes = await getEntryNotes(
          userId: userId,
          entryId: meeting.id,
          entryType: CalendarEntryType.meeting,
        );
        entries.add(CalendarEntry.fromMeeting(meeting, notes: notes));
      }
      
      // Sort by start time
      entries.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      yield entries;
    }
  }

  /// Get all calendar entries for a user (bookmarked sessions + approved meetings)
  Future<List<CalendarEntry>> getCalendarEntries({
    required String userId,
    required String eventId,
    required List<String> bookmarkedSessionIds,
  }) async {
    print('📅 CALENDAR: Fetching entries for user: $userId, event: $eventId');
    print('📅 CALENDAR: Bookmarked sessions: ${bookmarkedSessionIds.length} IDs');
    
    final List<CalendarEntry> entries = [];
    
    // Fetch bookmarked sessions
    final sessions = await _getBookmarkedSessions(eventId, bookmarkedSessionIds);
    print('📅 CALENDAR: Fetched ${sessions.length} sessions from DB');
    
    for (final session in sessions) {
      print('  📌 Session: ${session.id} - ${session.title}');
      entries.add(CalendarEntry.fromSession(session));
    }
    
    // Fetch approved meetings
    final meetings = await _getApprovedMeetings(userId);
    print('📅 CALENDAR: Fetched ${meetings.length} meetings from DB');
    
    for (final meeting in meetings) {
      print('  🤝 Meeting: ${meeting.id}');
      entries.add(CalendarEntry.fromMeeting(meeting));
    }
    
    print('📅 CALENDAR: Total entries created: ${entries.length}');
    
    // Sort by start time
    entries.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    return entries;
  }

  /// Get stream of bookmarked sessions for the current event
  Stream<List<Session>> _getBookmarkedSessionsStream(String eventId, List<String> sessionIds) {
    if (sessionIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .where(FieldPath.documentId, whereIn: sessionIds)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList());
  }

  /// Get stream of approved meetings for the user
  Stream<List<Meeting>> _getApprovedMeetingsStream(String userId) {
    return _firestore
        .collection('meetings')
        .where('memberIds', arrayContains: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList());
  }

  /// Get bookmarked sessions for the current event
  Future<List<Session>> _getBookmarkedSessions(String eventId, List<String> sessionIds) async {
    if (sessionIds.isEmpty) {
      return [];
    }

    final snapshot = await _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .where(FieldPath.documentId, whereIn: sessionIds)
        .get();
    
    return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
  }

  /// Get approved meetings for the user
  Future<List<Meeting>> _getApprovedMeetings(String userId) async {
    final snapshot = await _firestore
        .collection('meetings')
        .where('memberIds', arrayContains: userId)
        .where('status', isEqualTo: 'accepted')
        .get();
    
    return snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList();
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
