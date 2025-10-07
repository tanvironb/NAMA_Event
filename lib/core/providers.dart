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
import 'package:events_app_trueattempt/features/chat/data/chat_repository.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/features/qr_scanner/data/checkin_repository.dart';
import 'package:events_app_trueattempt/features/notifications/data/notification_repository.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:events_app_trueattempt/core/services/remote_config_service.dart';
import 'package:events_app_trueattempt/features/admin/data/admin_repository.dart';
import 'package:events_app_trueattempt/features/messaging/data/messaging_repository.dart';
import 'package:events_app_trueattempt/core/models/conversation_model.dart';
import 'package:events_app_trueattempt/features/leaderboard/data/leaderboard_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/features/meetings/data/meeting_repository.dart';

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

// Notification Service Provider
final notificationServiceProvider = Provider.family<NotificationService?, String>((ref, userId) {
  final userProfileRepo = ref.watch(userProfileRepositoryProvider);
  if (userId.isEmpty) return null;
  return NotificationService(userProfileRepo, userId);
});

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

// Provides a stream of sessions where a specific user is a speaker.
final speakerSessionsProvider = Provider.autoDispose.family<AsyncValue<List<Session>>, String>((ref, speakerId) {
  final allSessionsAsync = ref.watch(sessionsStreamProvider);
  
  return allSessionsAsync.when(
    data: (sessions) {
      final speakerSessions = sessions.where((session) => 
        session.speakerIds.contains(speakerId)
      ).toList();
      return AsyncValue.data(speakerSessions);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
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

// Provider for featured speakers (speakers from current/upcoming sessions)
final featuredSpeakersFutureProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final sessionsAsync = ref.watch(sessionsStreamProvider);
  
  return sessionsAsync.when(
    data: (sessions) async {
      if (sessions.isEmpty) return [];
      
      // Get unique speaker IDs from all sessions, prioritizing current/upcoming sessions
      final now = DateTime.now();
      final currentOrUpcomingSessions = sessions.where((session) => 
        session.endTime.isAfter(now) // Session hasn't ended yet
      ).toList();
      
      // Sort by priority and start time to get the most important speakers
      currentOrUpcomingSessions.sort((a, b) {
        // First by priority (higher first)
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        
        // Then by start time (sooner first for upcoming sessions)
        return a.startTime.compareTo(b.startTime);
      });
      
      // Get unique speaker IDs from top sessions (limit to avoid too many speakers)
      final Set<String> speakerIds = {};
      for (final session in currentOrUpcomingSessions.take(10)) {
        speakerIds.addAll(session.speakerIds);
      }
      
      if (speakerIds.isEmpty) return [];
      
      // Fetch speaker details
      final repo = ref.watch(userProfileRepositoryProvider);
      return await repo.getUsersByIds(speakerIds.toList());
    },
    loading: () => <AppUser>[],
    error: (err, stack) => <AppUser>[],
  );
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

// --- Chat Providers ---
final chatRepositoryProvider = Provider((ref) => ChatRepository(ref.watch(firestoreServiceProvider)));

final sessionChatStreamProvider = StreamProvider.autoDispose.family<List<Message>, String>((ref, sessionId) {
  return ref.watch(chatRepositoryProvider).getSessionMessagesStream(sessionId);
});

// --- Check-in Provider ---
final checkinRepositoryProvider = Provider((ref) => CheckinRepository(ref.watch(firestoreServiceProvider)));

final notificationRepositoryProvider = Provider((ref) => NotificationRepository(ref.watch(firestoreServiceProvider)));

// --- Meeting Providers ---
final meetingRepositoryProvider = Provider((ref) => MeetingRepository(ref.watch(firestoreServiceProvider)));

final meetingsStreamProvider = StreamProvider.autoDispose<List<Meeting>>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (userId != null) {
    return ref.watch(meetingRepositoryProvider).getMeetingsStream(userId);
  }
  return Stream.value([]);
});

final notificationsStreamProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (userId != null) {
    return ref.watch(notificationRepositoryProvider).getNotificationsStream(userId);
  }
  return Stream.value([]);
});

// --- Remote Config Providers ---
final firebaseRemoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) => FirebaseRemoteConfig.instance);

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService(ref.watch(firebaseRemoteConfigProvider));
});

final adminRepositoryProvider = Provider((ref) => AdminRepository(ref.watch(firestoreServiceProvider)));

final allUsersStreamProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllUsersStream();
});

// --- Messaging Providers ---
final messagingRepositoryProvider = Provider((ref) => MessagingRepository(ref.watch(firestoreServiceProvider)));

final conversationsStreamProvider = StreamProvider.autoDispose<List<Conversation>>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (userId == null) return Stream.value([]);
  return ref.watch(messagingRepositoryProvider).getConversationsStream(userId);
});

final directMessagesStreamProvider = StreamProvider.autoDispose.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(messagingRepositoryProvider).getDirectMessagesStream(conversationId);
});

final userSearchProvider = FutureProvider.autoDispose.family<List<AppUser>, String>((ref, query) {
  if (query.isEmpty) return [];
  return ref.watch(userProfileRepositoryProvider).searchUsers(query);
});

// --- Leaderboard Providers ---
final leaderboardRepositoryProvider = Provider((ref) => LeaderboardRepository(ref.watch(firestoreServiceProvider)));

final leaderboardFutureProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(leaderboardRepositoryProvider).getLeaderboardUsers();
});

// User Profile by ID Provider
final userProfileByIdProvider = FutureProvider.autoDispose.family<AppUser?, String>((ref, userId) {
  return ref.watch(userProfileRepositoryProvider).getUserProfile(userId);
});

// --- NEW: Firebase Functions Provider ---
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instance);

// --- Partner Sessions Provider ---
final partnerSessionsProvider = FutureProvider.autoDispose.family<List<Session>, String>((ref, partnerId) async {
  final repo = ref.watch(agendaRepositoryProvider);
  return await repo.getSessionsByPartnerId(partnerId);
});