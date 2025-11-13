// lib/features/calendar/widgets/overlap_handler.dart

import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';

/// Google Calendar-style column layout handler for overlapping entries
class OverlapHandler {
  /// Layout entries using Google Calendar's column-based algorithm
  /// Returns layout information for each entry (column, width, whether it overlaps)
  static List<EntryLayout> layoutEntries(List<CalendarEntry> entries) {
    if (entries.isEmpty) return [];

    // Sort entries by priority: Sessions > Longest > Earliest start
    final sortedEntries = List<CalendarEntry>.from(entries);
    sortedEntries.sort((a, b) {
      // Priority 1: Sessions before meetings
      if (a.type != b.type) {
        return a.type == CalendarEntryType.session ? -1 : 1;
      }
      
      // Priority 2: Longer duration first
      final durationCompare = b.durationMinutes.compareTo(a.durationMinutes);
      if (durationCompare != 0) return durationCompare;
      
      // Priority 3: Earlier start time
      final startCompare = a.startTime.compareTo(b.startTime);
      if (startCompare != 0) return startCompare;
      
      // Priority 4: Alphabetical by title
      return a.title.compareTo(b.title);
    });

    // Build layout for each entry
    final layouts = <EntryLayout>[];
    
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      
      // Find all entries that overlap with this one
      final overlappingEntries = sortedEntries.where((other) => 
        other != entry && entry.overlapsWith(other)
      ).toList();
      
      if (overlappingEntries.isEmpty) {
        // No overlap - full width
        layouts.add(EntryLayout(
          entry: entry,
          column: 0,
          totalColumns: 1,
          isOverlapping: false,
        ));
      } else {
        // Has overlaps - determine layout type
        final layout = _determineLayout(entry, overlappingEntries, sortedEntries);
        layouts.add(layout);
      }
    }

    return layouts;
  }

  /// Determine layout for an entry with overlaps
  static EntryLayout _determineLayout(
    CalendarEntry entry,
    List<CalendarEntry> overlappingEntries,
    List<CalendarEntry> allEntries,
  ) {
    // Find ALL entries (including this one) that start at similar time
    final allSimultaneous = [entry];
    
    for (final other in overlappingEntries) {
      final timeDiff = entry.startTime.difference(other.startTime).abs();
      if (timeDiff.inMinutes < 5) { // Within 5 minutes = simultaneous
        allSimultaneous.add(other);
      }
    }

    if (allSimultaneous.length > 1) {
      // COLUMN LAYOUT: Multiple entries start at similar time
      // Sort by priority within the group to determine column order
      allSimultaneous.sort((a, b) {
        // Priority 1: Sessions before meetings
        if (a.type != b.type) {
          return a.type == CalendarEntryType.session ? -1 : 1;
        }
        
        // Priority 2: Longer duration first
        final durationCompare = b.durationMinutes.compareTo(a.durationMinutes);
        if (durationCompare != 0) return durationCompare;
        
        // Priority 3: Earlier start time
        final startCompare = a.startTime.compareTo(b.startTime);
        if (startCompare != 0) return startCompare;
        
        // Priority 4: Alphabetical by title
        return a.title.compareTo(b.title);
      });
      
      final totalColumns = allSimultaneous.length;
      final column = allSimultaneous.indexOf(entry);
      
      return EntryLayout(
        entry: entry,
        column: column,
        totalColumns: totalColumns,
        isOverlapping: false,
      );
    } else {
      // OVERLAP LAYOUT: Entry starts during another long entry
      // This entry will overlap on top with outline + padding
      return EntryLayout(
        entry: entry,
        column: 0,
        totalColumns: 1,
        isOverlapping: true,
        overlapOffset: 0.15, // 15% offset from left
      );
    }
  }
}

/// Layout information for a calendar entry
class EntryLayout {
  final CalendarEntry entry;
  final int column; // Which column (0-based index)
  final int totalColumns; // Total columns in the layout
  final bool isOverlapping; // Whether this overlaps another entry (with outline)
  final double overlapOffset; // Left offset when overlapping (0.0 - 1.0)

  EntryLayout({
    required this.entry,
    required this.column,
    required this.totalColumns,
    required this.isOverlapping,
    this.overlapOffset = 0.0,
  });

  /// Calculate left position factor (0.0 = left edge, 1.0 = right edge)
  double get leftFactor {
    if (isOverlapping) {
      return overlapOffset;
    }
    return column / totalColumns;
  }

  /// Calculate width factor (0.0 - 1.0 of available space)
  double get widthFactor {
    if (isOverlapping) {
      return 1.0 - overlapOffset; // Take remaining space after offset
    }
    return 1.0 / totalColumns;
  }
}

