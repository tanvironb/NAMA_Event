// lib/features/calendar/models/calendar_entry.dart

import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';

/// Unified model for calendar entries (sessions or meetings)
class CalendarEntry {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final CalendarEntryType type;
  final String location;
  final String? notes; // User-added custom notes (optional)
  
  // Original data references
  final Session? session;
  final Meeting? meeting;

  CalendarEntry({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.location,
    this.notes,
    this.session,
    this.meeting,
  });

  /// Create CalendarEntry from Session
  factory CalendarEntry.fromSession(Session session, {String? notes}) {
    return CalendarEntry(
      id: session.id,
      title: session.title,
      startTime: session.startTime,
      endTime: session.endTime,
      type: CalendarEntryType.session,
      location: session.location,
      notes: notes,
      session: session,
    );
  }

  /// Create CalendarEntry from Meeting
  factory CalendarEntry.fromMeeting(Meeting meeting, {String? notes}) {
    return CalendarEntry(
      id: meeting.id,
      title: 'Meeting', // We'll enhance this in UI with participant name
      startTime: meeting.proposedTime.toDate(),
      endTime: meeting.proposedTime.toDate().add(const Duration(hours: 1)), // Default 1 hour duration
      type: CalendarEntryType.meeting,
      location: meeting.location,
      notes: notes,
      meeting: meeting,
    );
  }

  /// Check if this entry overlaps with another entry
  bool overlapsWith(CalendarEntry other) {
    return (startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime));
  }

  /// Get duration in minutes
  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  /// Get hour of start time (for positioning in timeline)
  int get startHour {
    return startTime.hour;
  }

  /// Get minutes offset from start hour (for fine-grained positioning)
  int get startMinuteOffset {
    return startTime.minute;
  }

  /// Calculate position in hour row (0.0 to 1.0)
  /// e.g., 10:30 returns 0.5 (halfway through the 10 AM hour)
  double get hourPosition {
    return startTime.minute / 60.0;
  }

  /// Calculate how many hour rows this entry spans
  /// e.g., 10:30-11:30 spans 2 rows (partial 10, partial 11)
  int get rowSpan {
    final startHourIndex = startTime.hour;
    final endHourIndex = endTime.hour + (endTime.minute > 0 ? 1 : 0);
    return endHourIndex - startHourIndex;
  }

  /// Get color based on entry type
  /// Navy blue for sessions, Golden yellow for meetings
  String get colorHex {
    switch (type) {
      case CalendarEntryType.session:
        return '#1B1464'; // NAMA Navy Blue
      case CalendarEntryType.meeting:
        return '#E4B544'; // NAMA Golden Yellow
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarEntry && other.id == id && other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode;
}
