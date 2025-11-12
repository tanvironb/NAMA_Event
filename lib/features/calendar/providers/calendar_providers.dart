// lib/features/calendar/providers/calendar_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/calendar/data/calendar_repository.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';

/// Provider for CalendarRepository
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CalendarRepository(firestore);
});

/// Provider for calendar entries stream
final calendarEntriesProvider = StreamProvider<List<CalendarEntry>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  final userAsync = ref.watch(userAppProfileStreamProvider);
  final activeEventAsync = ref.watch(activeEventFutureProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) {
        return Stream.value([]);
      }

      final eventId = activeEventAsync.asData?.value.id;
      if (eventId == null) {
        return Stream.value([]);
      }

      return repository.getCalendarEntries(
        userId: user.uid,
        eventId: eventId,
        bookmarkedSessionIds: user.bookmarkedSessions,
      );
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
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
final entriesForDateProvider = Provider.family<List<CalendarEntry>, DateTime>((ref, date) {
  final groupedEntries = ref.watch(calendarEntriesByDateProvider);
  
  final normalizedDate = DateTime(date.year, date.month, date.day);
  return groupedEntries[normalizedDate] ?? [];
});
