import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:events_app_trueattempt/core/services/storage_service.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/models/event_model.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/models/sponsor_model.dart';
import 'package:events_app_trueattempt/core/models/venue_map_model.dart';
import 'package:events_app_trueattempt/features/profile/data/profile_repository.dart';
import 'package:events_app_trueattempt/features/explore/data/explore_repository.dart';
import 'package:events_app_trueattempt/features/agenda/data/agenda_repository.dart';
import 'package:events_app_trueattempt/features/directories/data/directory_repository.dart';
import 'package:events_app_trueattempt/features/chat/data/chat_repository.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/features/qr_scanner/data/checkin_repository.dart';
import 'package:events_app_trueattempt/features/notifications/data/notification_repository.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
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
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// --- Auth State Provider ---
final authStateChangesProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

// --- Core Service Provider ---
final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(ref.watch(firestoreProvider)),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

// --- App Initialization Provider ---
final appInitializationProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
});

// --- Repository Providers ---
final userProfileRepositoryProvider = Provider(
  (ref) => UserProfileRepository(
    ref.watch(firestoreServiceProvider),
    ref.watch(storageServiceProvider),
  ),
);

final eventRepositoryProvider = Provider(
  (ref) => EventRepository(ref.watch(firestoreServiceProvider)),
);

final agendaRepositoryProvider = Provider(
  (ref) => AgendaRepository(ref.watch(firestoreServiceProvider)),
);

final sponsorRepositoryProvider = Provider(
  (ref) => SponsorRepository(ref.watch(firestoreServiceProvider)),
);

final directoryRepositoryProvider = Provider(
  (ref) => DirectoryRepository(ref.watch(firestoreServiceProvider)),
);

final notificationServiceProvider =
    Provider.family<NotificationService?, String>((ref, userId) {
  final userProfileRepo = ref.watch(userProfileRepositoryProvider);

  if (userId.isEmpty) return null;

  return NotificationService(userProfileRepo, userId);
});

// --- App Data Providers ---
final activeEventFutureProvider = FutureProvider<Event>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final repo = ref.watch(eventRepositoryProvider);
  final currentUser = auth.currentUser;

  if (currentUser == null) {
    throw StateError('No signed-in user found.');
  }

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .get();

  final userData = userDoc.data();

  if (userData == null) {
    throw StateError('User profile was not found.');
  }

  final role = _normalizeEventRole(
    userData['role'] ??
        userData['userRole'] ??
        userData['userType'] ??
        userData['type'],
  );

  if (role == 'speaker' || role == 'moderator') {
    final candidateEventIds = <String>[];

    void addCandidate(dynamic value) {
      final eventId = (value ?? '').toString().trim();

      if (eventId.isNotEmpty && !candidateEventIds.contains(eventId)) {
        candidateEventIds.add(eventId);
      }
    }

    // Prefer the event most recently assigned by the backend.
    addCandidate(userData['currentEventId']);
    addCandidate(userData['activeEventId']);

    final rawEventIds = userData['eventIds'];

    if (rawEventIds is List) {
      for (final value in rawEventIds.reversed) {
        addCandidate(value);
      }
    }

    for (final eventId in candidateEventIds) {
      final assignedEvent = await repo.getEventById(eventId);

      if (assignedEvent != null) {
        return assignedEvent;
      }
    }

    // Never send a speaker/moderator to an unrelated global event.
    throw StateError(
      'No valid assigned event was found for this ${role == 'speaker' ? 'speaker' : 'moderator'}.',
    );
  }

  // Admin, staff and attendees continue to use the global active event.
  return repo.getActiveEvent();
});

String _normalizeEventRole(dynamic value) {
  final role = (value ?? '').toString().trim().toLowerCase();

  if (role == 'speaker_user' ||
      role == 'speaker user' ||
      role == 'speaker-user') {
    return 'speaker';
  }

  if (role == 'moderator_user' ||
      role == 'moderator user' ||
      role == 'moderator-user' ||
      role == 'mod') {
    return 'moderator';
  }

  if (role == 'administrator' || role == 'admins') {
    return 'admin';
  }

  if (role == 'staff_user' ||
      role == 'staff user' ||
      role == 'staff-user') {
    return 'staff';
  }

  if (role == 'delegate' || role == 'delegates' || role == 'user') {
    return 'attendee';
  }

  return role;
}


final userAppProfileStreamProvider =
    StreamProvider.autoDispose<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final repo = ref.watch(userProfileRepositoryProvider);

  if (auth.currentUser != null) {
    return repo.getUserProfileStream(auth.currentUser!.uid);
  }

  return Stream.value(null);
});

final sessionsStreamProvider = StreamProvider.autoDispose<List<Session>>((ref) {
  final eventAsync = ref.watch(activeEventFutureProvider);
  final repo = ref.watch(agendaRepositoryProvider);

  final eventId = eventAsync.asData?.value.id;

  if (eventId != null) {
    return repo.getSessionsStream(eventId);
  }

  return Stream.value([]);
});

final sessionStreamProvider =
    StreamProvider.autoDispose.family<Session?, String>((ref, sessionId) {
  return FirebaseFirestore.instance
      .collection('sessions')
      .doc(sessionId)
      .snapshots()
      .map((doc) => doc.exists ? Session.fromFirestore(doc) : null);
});

final speakerSessionsProvider =
    Provider.autoDispose.family<AsyncValue<List<Session>>, String>(
  (ref, userId) {
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    return allSessionsAsync.when(
      data: (sessions) {
        final assignedSessions = sessions
            .where(
              (session) =>
                  session.speakerIds.contains(userId) ||
                  session.moderatorIds.contains(userId),
            )
            .toList();

        return AsyncValue.data(assignedSessions);
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
    );
  },
);

final sponsorsStreamProvider = StreamProvider.autoDispose<List<Sponsor>>((ref) {
  final eventAsync = ref.watch(activeEventFutureProvider);
  final repo = ref.watch(sponsorRepositoryProvider);

  final eventId = eventAsync.asData?.value.id;

  if (eventId != null) {
    return repo.getSponsorsStream(eventId);
  }

  return Stream.value([]);
});

final venueMapsStreamProvider =
    StreamProvider.autoDispose<List<VenueMap>>((ref) {
  final eventAsync = ref.watch(activeEventFutureProvider);
  final eventId = eventAsync.asData?.value.id;

  if (eventId != null) {
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) {
      final venueMaps = <VenueMap>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final venueImageUrl = (data['venueImageUrl'] ?? '').toString().trim();

        if (venueImageUrl.isEmpty) continue;

        final location = (data['location'] ?? '').toString().trim();
        final sessionTitle = (data['title'] ?? '').toString().trim();
        final description = (data['description'] ?? '').toString().trim();

        venueMaps.add(
          VenueMap(
            id: doc.id,
            title: location.isNotEmpty
                ? location
                : sessionTitle.isNotEmpty
                    ? sessionTitle
                    : 'Venue',
            description: description,
            floor: '',
            imageUrls: [venueImageUrl],
            order: 0,
          ),
        );
      }

      return venueMaps;
    });
  }

  return Stream.value([]);
});

final sessionSpeakersFutureProvider =
    FutureProvider.family<List<AppUser>, List<String>>((ref, speakerIds) async {
  if (speakerIds.isEmpty) return [];

  final repo = ref.watch(userProfileRepositoryProvider);

  return await repo.getUsersByIds(speakerIds);
});

// --- Directory Providers ---
final attendeesFutureProvider =
    FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final activeEvent = await ref.watch(activeEventFutureProvider.future);

  return ref.watch(directoryRepositoryProvider).getAttendees(activeEvent.id);
});

final speakersFutureProvider =
    FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final activeEvent = await ref.watch(activeEventFutureProvider.future);

  return ref.watch(directoryRepositoryProvider).getSpeakers(activeEvent.id);
});

final featuredSpeakersFutureProvider =
    FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final sessionsAsync = ref.watch(sessionsStreamProvider);

  return sessionsAsync.when(
    data: (sessions) async {
      if (sessions.isEmpty) return [];

      final now = DateTime.now();

      final currentOrUpcomingSessions =
          sessions.where((session) => session.endTime.isAfter(now)).toList();

      currentOrUpcomingSessions.sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);

        if (priorityCompare != 0) return priorityCompare;

        return a.startTime.compareTo(b.startTime);
      });

      final Set<String> featuredUserIds = {};

      for (final session in currentOrUpcomingSessions.take(10)) {
        featuredUserIds.addAll(session.speakerIds);
        featuredUserIds.addAll(session.moderatorIds);
      }

      if (featuredUserIds.isEmpty) return [];

      final repo = ref.watch(userProfileRepositoryProvider);

      return await repo.getUsersByIds(featuredUserIds.toList());
    },
    loading: () => <AppUser>[],
    error: (err, stack) => <AppUser>[],
  );
});

final activeLiveSessionProvider = StreamProvider.autoDispose<Session?>((ref) {
  final eventAsync = ref.watch(activeEventFutureProvider);
  final repo = ref.watch(agendaRepositoryProvider);

  return eventAsync.when(
    data: (event) {
      return repo.getSessionsStream(event.id).map((sessions) {
        final now = DateTime.now();

        final activeLiveSessions = sessions.where((session) {
          final isCurrentlyActive =
              now.isAfter(session.startTime) && now.isBefore(session.endTime);
          final hasLiveStream = session.liveStreamUrl.isNotEmpty;

          return isCurrentlyActive && hasLiveStream;
        }).toList();

        if (activeLiveSessions.isEmpty) return null;

        activeLiveSessions.sort((a, b) {
          final priorityComparison = b.priority.compareTo(a.priority);

          if (priorityComparison != 0) return priorityComparison;

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
final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(ref.watch(firestoreServiceProvider)),
);

final sessionChatStreamProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, sessionId) {
  return ref.watch(chatRepositoryProvider).getSessionMessagesStream(sessionId);
});

// --- Check-in Provider ---
final checkinRepositoryProvider = Provider(
  (ref) => CheckinRepository(ref.watch(firestoreServiceProvider)),
);

// --- Notification Providers ---
final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(firestoreServiceProvider)),
);

final notificationsStreamProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  final activeEventAsync = ref.watch(activeEventFutureProvider);

  if (userId == null) return Stream.value([]);

  return activeEventAsync.when(
    data: (event) {
      return ref.watch(notificationRepositoryProvider).getNotificationsStream(
            userId: userId,
            eventId: event.id,
          );
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final unreadNotificationsCountProvider =
    StreamProvider.autoDispose<int>((ref) {
  return ref.watch(notificationsStreamProvider).when(
        data: (notifications) {
          return Stream.value(
            notifications
                .where((n) => !n.isRead && n.type != AppNotificationType.chat)
                .length,
          );
        },
        loading: () => Stream.value(0),
        error: (_, __) => Stream.value(0),
      );
});

// --- Meeting Providers ---
final meetingRepositoryProvider = Provider(
  (ref) => MeetingRepository(ref.watch(firestoreServiceProvider)),
);

final meetingsStreamProvider = StreamProvider.autoDispose<List<Meeting>>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  final activeEventAsync = ref.watch(activeEventFutureProvider);

  if (userId == null) return Stream.value([]);

  return activeEventAsync.when(
    data: (event) {
      return ref.watch(meetingRepositoryProvider).getMeetingsStream(
            userId: userId,
            eventId: event.id,
          );
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// --- Remote Config Providers ---
final firebaseRemoteConfigProvider =
    Provider<FirebaseRemoteConfig>((ref) => FirebaseRemoteConfig.instance);

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService(ref.watch(firebaseRemoteConfigProvider));
});

// --- Admin Providers ---
final adminRepositoryProvider = Provider(
  (ref) => AdminRepository(ref.watch(firestoreServiceProvider)),
);

final allUsersStreamProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllUsersStream();
});

// --- Messaging Providers ---
final messagingRepositoryProvider = Provider(
  (ref) => MessagingRepository(ref.watch(firestoreServiceProvider)),
);

final conversationsStreamProvider =
    StreamProvider.autoDispose<List<Conversation>>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  final activeEventAsync = ref.watch(activeEventFutureProvider);

  if (userId == null) return Stream.value([]);

  return activeEventAsync.when(
    data: (event) {
      return ref.watch(messagingRepositoryProvider).getConversationsStream(
            userId: userId,
            eventId: event.id,
          );
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final directMessagesStreamProvider =
    StreamProvider.autoDispose.family<List<Message>, String>(
  (ref, conversationId) {
    return ref
        .watch(messagingRepositoryProvider)
        .getDirectMessagesStream(conversationId);
  },
);

final userSearchProvider =
    FutureProvider.autoDispose.family<List<AppUser>, String>((ref, query) {
  if (query.isEmpty) return [];

  return ref.watch(userProfileRepositoryProvider).searchUsers(query);
});

final unreadConversationsCountProvider =
    StreamProvider.autoDispose<int>((ref) {
  final conversationsAsync = ref.watch(conversationsStreamProvider);
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

  if (userId == null) return Stream.value(0);

  return conversationsAsync.when(
    data: (conversations) {
      final count = conversations
          .where((conv) => conv.getUnreadCountForUser(userId) > 0)
          .length;

      return Stream.value(count);
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

// --- Leaderboard Providers ---
final leaderboardRepositoryProvider = Provider(
  (ref) => LeaderboardRepository(ref.watch(firestoreServiceProvider)),
);

final leaderboardFutureProvider =
    FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(leaderboardRepositoryProvider).getLeaderboardUsers();
});

final userProfileByIdProvider =
    FutureProvider.autoDispose.family<AppUser?, String>((ref, userId) {
  return ref.watch(userProfileRepositoryProvider).getUserProfile(userId);
});

// --- Firebase Functions Provider ---
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  // For local development with emulator, uncomment this:
  // if (kDebugMode) {
  //   functions.useFunctionsEmulator('localhost', 5001);
  // }

  return functions;
});

// --- Partner Sessions Provider ---
final partnerSessionsProvider =
    FutureProvider.autoDispose.family<List<Session>, String>(
  (ref, partnerId) async {
    final repo = ref.watch(agendaRepositoryProvider);

    return await repo.getSessionsByPartnerId(partnerId);
  },
);