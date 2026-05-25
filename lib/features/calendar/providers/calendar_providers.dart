// lib/features/calendar/providers/calendar_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/calendar/data/calendar_repository.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(FirebaseFirestore.instance);
});

final calendarEntriesProvider =
    StreamProvider.autoDispose<List<CalendarEntry>>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  final activeEventAsync = ref.watch(activeEventFutureProvider);
  final userProfileAsync = ref.watch(userAppProfileStreamProvider);

  if (userId == null) {
    return Stream.value([]);
  }

  final activeEvent = activeEventAsync.asData?.value;
  final userProfile = userProfileAsync.asData?.value;

  if (activeEvent == null || userProfile == null) {
    return Stream.value([]);
  }

  final role = userProfile.role.toLowerCase().trim();

  final includeSessions = role != 'speaker' && role != 'admin';

  final bookmarkedSessionIds = _extractBookmarkedSessionIds(userProfile);

  return ref.watch(calendarRepositoryProvider).getCalendarEntriesStream(
        userId: userId,
        eventId: activeEvent.id,
        bookmarkedSessionIds: bookmarkedSessionIds,
        includeSessions: includeSessions,
      );
});

final calendarEntriesByDateProvider =
    Provider.autoDispose<Map<DateTime, List<CalendarEntry>>>((ref) {
  final entriesAsync = ref.watch(calendarEntriesProvider);

  final entries = entriesAsync.asData?.value ?? [];

  final Map<DateTime, List<CalendarEntry>> groupedEntries = {};

  for (final entry in entries) {
    final date = DateTime(
      entry.startTime.year,
      entry.startTime.month,
      entry.startTime.day,
    );

    groupedEntries.putIfAbsent(date, () => []);
    groupedEntries[date]!.add(entry);
  }

  for (final dayEntries in groupedEntries.values) {
    dayEntries.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  return groupedEntries;
});

final entriesForDateProvider =
    Provider.autoDispose.family<AsyncValue<List<CalendarEntry>>, DateTime>(
  (ref, selectedDate) {
    final entriesAsync = ref.watch(calendarEntriesProvider);

    return entriesAsync.when(
      data: (entries) {
        final filteredEntries = entries.where((entry) {
          return entry.startTime.year == selectedDate.year &&
              entry.startTime.month == selectedDate.month &&
              entry.startTime.day == selectedDate.day;
        }).toList();

        filteredEntries.sort((a, b) => a.startTime.compareTo(b.startTime));

        return AsyncValue.data(filteredEntries);
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    );
  },
);

final selectedCalendarEntryProvider =
    StateProvider.autoDispose<CalendarEntry?>((ref) => null);

final calendarEntryNotesProvider =
    FutureProvider.autoDispose.family<String?, CalendarEntry>((ref, entry) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

  if (userId == null) {
    return Future.value(null);
  }

  return ref.watch(calendarRepositoryProvider).getEntryNotes(
        userId: userId,
        entryId: entry.id,
        entryType: entry.type,
      );
});

Future<void> saveCalendarEntryNotes({
  required WidgetRef ref,
  required CalendarEntry entry,
  required String notes,
}) async {
  final userId = ref.read(firebaseAuthProvider).currentUser?.uid;

  if (userId == null) {
    throw Exception('User not logged in');
  }

  await ref.read(calendarRepositoryProvider).saveEntryNotes(
        userId: userId,
        entryId: entry.id,
        entryType: entry.type,
        notes: notes,
      );

  ref.invalidate(calendarEntryNotesProvider(entry));
  ref.invalidate(calendarEntriesProvider);
  ref.invalidate(calendarEntriesByDateProvider);
}

List<String> _extractBookmarkedSessionIds(dynamic userProfile) {
  try {
    final bookmarkedSessions = userProfile.bookmarkedSessions;
    if (bookmarkedSessions is List) {
      return bookmarkedSessions.map((id) => id.toString()).toList();
    }
  } catch (_) {}

  try {
    final bookmarkedSessionIds = userProfile.bookmarkedSessionIds;
    if (bookmarkedSessionIds is List) {
      return bookmarkedSessionIds.map((id) => id.toString()).toList();
    }
  } catch (_) {}

  try {
    final savedSessionIds = userProfile.savedSessionIds;
    if (savedSessionIds is List) {
      return savedSessionIds.map((id) => id.toString()).toList();
    }
  } catch (_) {}

  return [];
}