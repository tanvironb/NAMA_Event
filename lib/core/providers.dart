import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/models/event_model.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/models/sponsor_model.dart';
import 'package:events_app_trueattempt/features/profile/data/profile_repository.dart';
import 'package:events_app_trueattempt/features/explore/data/explore_repository.dart';
import 'package:events_app_trueattempt/features/agenda/data/agenda_repository.dart';
import 'package:events_app_trueattempt/features/directories/data/directory_repository.dart';

// --- Firebase Core Providers ---
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// --- Auth State Provider ---
// Provides a stream of the current user's authentication state (Firebase User object).
// Used by AuthGate to decide whether to show login or home screen.
final authStateChangesProvider = StreamProvider<User?>(
    (ref) => ref.watch(firebaseAuthProvider).authStateChanges());

// --- Core Service Provider ---
// Provides an instance of our FirestoreService for interacting with raw Firestore data.
final firestoreServiceProvider = Provider<FirestoreService>(
    (ref) => FirestoreService(ref.watch(firestoreProvider)));

// --- Repository Providers (for data layer abstraction) ---
// These abstract direct FirestoreService calls and work with domain models.

// User Repository Provider
final userProfileRepositoryProvider = Provider((ref) => UserProfileRepository(ref.watch(firestoreServiceProvider)));

// Event Repository Provider
final eventRepositoryProvider = Provider((ref) => EventRepository(ref.watch(firestoreServiceProvider)));

// Agenda Repository Provider
final agendaRepositoryProvider = Provider((ref) => AgendaRepository(ref.watch(firestoreServiceProvider)));

// Sponsor Repository Provider
final sponsorRepositoryProvider = Provider((ref) => SponsorRepository(ref.watch(firestoreServiceProvider)));

// --- App Data Providers (for presentation layer consumption) ---

// Provides the active event as a Future.
final activeEventFutureProvider = FutureProvider<Event>((ref) async {
  final repo = ref.watch(eventRepositoryProvider);
  return await repo.getActiveEvent();
});

// Provides a stream of the currently logged-in user's AppUser profile data.
final userAppProfileStreamProvider = StreamProvider.autoDispose<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final repo = ref.watch(userProfileRepositoryProvider);
  if (auth.currentUser != null) {
    return repo.getUserProfileStream(auth.currentUser!.uid);
  }
  return Stream.value(null);
});

// Provides a stream of sessions for the active event.
final sessionsStreamProvider = StreamProvider.autoDispose<List<Session>>((ref) {
  final eventAsync = ref.watch(activeEventFutureProvider);
  final repo = ref.watch(agendaRepositoryProvider);

  final eventId = eventAsync.asData?.value.id;
  if (eventId != null) {
    return repo.getSessionsStream(eventId);
  }
  return Stream.value([]); // Return empty list if no active event is found
});

// Provides a stream of sponsors for the active event.
final sponsorsStreamProvider = StreamProvider.autoDispose<List<Sponsor>>((ref) {
  final eventAsync = ref.watch(activeEventFutureProvider);
  final repo = ref.watch(sponsorRepositoryProvider);

  final eventId = eventAsync.asData?.value.id;
  if (eventId != null) {
    return repo.getSponsorsStream(eventId);
  }
  return Stream.value([]); // Return empty list if no active event is found
});

// Provides speaker details for a given list of speaker UIDs.
// Uses FutureProvider.family to allow passing parameters (speakerIds) to the provider.
final sessionSpeakersFutureProvider =
    FutureProvider.family<List<AppUser>, List<String>>(
        (ref, speakerIds) async {
  if (speakerIds.isEmpty) return [];
  final repo = ref.watch(userProfileRepositoryProvider);
  return await repo.getUsersByIds(speakerIds);
});

final directoryRepositoryProvider = Provider((ref) => DirectoryRepository(ref.watch(firestoreServiceProvider)));

final attendeesFutureProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(directoryRepositoryProvider).getAttendees();
});

final speakersFutureProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(directoryRepositoryProvider).getSpeakers();
});

// Provides the currently active live session (session happening right now)
final activeLiveSessionProvider = StreamProvider.autoDispose<Session?>((ref) {
  final eventAsync = ref.watch(activeEventFutureProvider);
  final repo = ref.watch(agendaRepositoryProvider);
  
  return eventAsync.when(
    data: (event) {
      return repo.getSessionsStream(event.id).map((sessions) {
        final now = DateTime.now();
        
        // Find sessions that are currently active (started but not ended) and have a live stream URL
        final activeLiveSessions = sessions.where((session) {
          final isCurrentlyActive = now.isAfter(session.startTime) && now.isBefore(session.endTime);
          final hasLiveStream = session.liveStreamUrl.isNotEmpty;
          return isCurrentlyActive && hasLiveStream;
        }).toList();
        
        // If no active live sessions, return null
        if (activeLiveSessions.isEmpty) return null;
        
        // If multiple active live sessions, select the highest priority one
        // Priority scale: 1-5 where 5 is most urgent (keynotes, main events)
        // Sort by priority (descending) then by start time (most recent first) as tiebreaker
        activeLiveSessions.sort((a, b) {
          // First compare by priority (higher priority first)
          final priorityComparison = b.priority.compareTo(a.priority);
          if (priorityComparison != 0) return priorityComparison;
          
          // If same priority, prefer the session that started more recently
          return b.startTime.compareTo(a.startTime);
        });
        
        return activeLiveSessions.first;
      });
    },
    loading: () => Stream.value(null),
    error: (err, stack) => Stream.value(null),
  );
});