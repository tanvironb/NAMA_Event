// lib/features/calendar/widgets/overlap_handler.dart

import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';

/// Helper class to handle overlapping calendar entries
class OverlapHandler {
  /// Group entries by overlaps and assign positions
  static List<OverlapGroup> groupOverlappingEntries(List<CalendarEntry> entries) {
    final List<OverlapGroup> groups = [];
    final Set<CalendarEntry> processed = {};

    for (final entry in entries) {
      if (processed.contains(entry)) continue;

      // Find all entries that overlap with this one
      final overlapping = entries.where((other) {
        return !processed.contains(other) && entry.overlapsWith(other);
      }).toList();

      if (overlapping.isEmpty) {
        // No overlaps - single entry group
        groups.add(OverlapGroup(entries: [entry], positions: [0]));
        processed.add(entry);
      } else {
        // Has overlaps - create group
        overlapping.sort((a, b) {
          // Sort by start time, then by type (sessions first)
          final timeCompare = a.startTime.compareTo(b.startTime);
          if (timeCompare != 0) return timeCompare;
          
          // Same start time: session comes before meeting
          if (a.type != b.type) {
            return a.type == CalendarEntryType.session ? -1 : 1;
          }
          return 0;
        });

        final positions = _assignPositions(overlapping);
        groups.add(OverlapGroup(entries: overlapping, positions: positions));
        processed.addAll(overlapping);
      }
    }

    return groups;
  }

  /// Assign left/right positions to overlapping entries
  /// Returns list of positions (0 = left, 1 = right)
  static List<int> _assignPositions(List<CalendarEntry> entries) {
    if (entries.length <= 2) {
      return List.generate(entries.length, (index) => index);
    }

    // For 3+ entries, assign positions and mark overflow
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

  /// Check if overlap group has more items than can be displayed
  static bool hasOverflow(OverlapGroup group) {
    return group.entries.length > 3; // Show "+N more" if more than 3 items
  }

  /// Get count of overflow items
  static int getOverflowCount(OverlapGroup group) {
    return group.entries.length > 3 ? group.entries.length - 2 : 0;
  }
}

/// Represents a group of overlapping entries
class OverlapGroup {
  final List<CalendarEntry> entries;
  final List<int> positions; // Position for each entry (0 = left, 1 = right, 2 = overflow)

  OverlapGroup({
    required this.entries,
    required this.positions,
  });

  bool get hasOverflow => entries.length > 3;
  
  int get overflowCount => entries.length > 3 ? entries.length - 2 : 0;
  
  List<CalendarEntry> get visibleEntries => entries.take(2).toList();
  
  List<CalendarEntry> get overflowEntries => entries.skip(2).toList();
}
