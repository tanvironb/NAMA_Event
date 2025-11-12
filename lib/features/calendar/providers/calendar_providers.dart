// lib/features/calendar/providers/calendar_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/calendar/data/calendar_repository.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';

/// Provider for CalendarRepository
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(firestoreProvider));
});

/// Stream provider for calendar entries (bookmarked sessions + approved meetings)
/// Watches for real-time updates to sessions and meetings
final calendarEntriesProvider = StreamProvider.autoDispose<List<CalendarEntry>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  final userAsync = ref.watch(userAppProfileStreamProvider);
  final activeEventAsync = ref.watch(activeEventFutureProvider);

  // Extract user and event from AsyncValue using .asData?.value pattern (existing system pattern)
  final user = userAsync.asData?.value;
  if (user == null) {
    return Stream.value([]);
  }

  final event = activeEventAsync.asData?.value;
  if (event == null) {
    return Stream.value([]);
  }
  
  return repository.getCalendarEntriesStream(
    userId: user.uid,
    eventId: event.id,
    bookmarkedSessionIds: user.bookmarkedSessions,
  );
});

/// Provider for entries grouped by date
final calendarEntriesByDateProvider = Provider<Map<DateTime, List<CalendarEntry>>>((ref) {
  final entriesAsync = ref.watch(calendarEntriesProvider);

  return entriesAsync.when(
    data: (entries) {
      final Map<DateTime, List<CalendarEntry>> grouped = {};

      for (final entry in entries) {
        final date = DateTime(
          entry.startTime.year,
          entry.startTime.month,
          entry.startTime.day,
        );

        if (!grouped.containsKey(date)) {
          grouped[date] = [];
        }
        grouped[date]!.add(entry);
      }

      return grouped;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Provider for entries on a specific date
final entriesForDateProvider = Provider.autoDispose.family<AsyncValue<List<CalendarEntry>>, DateTime>((ref, date) {
  final entriesAsync = ref.watch(calendarEntriesProvider);
  
  return entriesAsync.when(
    data: (entries) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final filtered = entries.where((entry) {
        final entryDate = DateTime(
          entry.startTime.year,
          entry.startTime.month,
          entry.startTime.day,
        );
        return entryDate == normalizedDate;
      }).toList();
      
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
