// lib/features/calendar/widgets/overlap_handler.dart

import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';

/// Helper class to handle overlapping calendar entries with proper conflict detection
class OverlapHandler {
  /// Group entries by actual time conflicts (not just hour overlap)
  /// This ensures entries can share space if they don't actually conflict in time
  static List<OverlapGroup> groupOverlappingEntries(List<CalendarEntry> entries) {
    final List<OverlapGroup> groups = [];
    final Set<CalendarEntry> processed = {};

    // Sort entries by start time
    final sortedEntries = List<CalendarEntry>.from(entries);
    sortedEntries.sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final entry in sortedEntries) {
      if (processed.contains(entry)) continue;

      // Find all entries that ACTUALLY overlap with this one in time
      // Not just in the same hour, but actually conflict
      final conflicting = <CalendarEntry>[];
      conflicting.add(entry); // Add self first
      
      for (final other in sortedEntries) {
        if (processed.contains(other) || other == entry) continue;
        
        // Check if this entry conflicts with ANY entry already in the group
        bool hasConflict = false;
        for (final existing in conflicting) {
          if (existing.overlapsWith(other)) {
            hasConflict = true;
            break;
          }
        }
        
        if (hasConflict) {
          conflicting.add(other);
        }
      }

      // Sort conflicting entries by priority: 1) Sessions first, 2) Longest duration
      conflicting.sort((a, b) {
        // Priority 1: Sessions before meetings
        if (a.type != b.type) {
          return a.type == CalendarEntryType.session ? -1 : 1;
        }
        
        // Priority 2: Longer duration first
        return b.durationMinutes.compareTo(a.durationMinutes);
      });

      final positions = _assignPositions(conflicting);
      groups.add(OverlapGroup(entries: conflicting, positions: positions));
      processed.addAll(conflicting);
    }

    return groups;
  }

  /// Assign left/right positions to conflicting entries
  /// Returns list of positions (0 = left, 1 = right, 2+ = overflow)
  static List<int> _assignPositions(List<CalendarEntry> entries) {
    if (entries.length == 1) {
      return [0]; // Single entry gets full width (position 0, but will be rendered differently)
    }
    
    if (entries.length == 2) {
      return [0, 1]; // Two entries side by side
    }

    // For 3+ entries, first two get positions, rest are overflow
    final List<int> positions = [];
    for (int i = 0; i < entries.length; i++) {
      if (i < 2) {
        positions.add(i); // First two get positions 0 and 1
      } else {
        positions.add(2); // Rest are in overflow (position 2)
      }
    }
    return positions;
  }
}

/// Represents a group of conflicting entries (entries that actually overlap in time)
class OverlapGroup {
  final List<CalendarEntry> entries;
  final List<int> positions; // Position for each entry (0 = left/full, 1 = right, 2 = overflow)

  OverlapGroup({
    required this.entries,
    required this.positions,
  });

  bool get hasOverflow => entries.length > 2;
  
  int get overflowCount => entries.length > 2 ? entries.length - 2 : 0;
  
  List<CalendarEntry> get visibleEntries => entries.take(2).toList();
  
  List<CalendarEntry> get overflowEntries => entries.skip(2).toList();
  
  /// Get the earliest start time in this group
  DateTime get groupStartTime {
    return entries.map((e) => e.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
  }
  
  /// Get the latest end time in this group
  DateTime get groupEndTime {
    return entries.map((e) => e.endTime).reduce((a, b) => a.isAfter(b) ? a : b);
  }
}
