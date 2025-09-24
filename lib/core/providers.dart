import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

// --- Firebase Core Providers ---
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// --- Authentication State Provider ---
// Provides a stream of the current user's authentication state.
// This is used by AuthGate to decide whether to show login or home screen.
final authStateChangesProvider = StreamProvider<User?>(
    (ref) => ref.watch(firebaseAuthProvider).authStateChanges());

// --- Service Provider ---
// Provides an instance of our FirestoreService for interacting with Firestore.
final firestoreServiceProvider = Provider<FirestoreService>(
    (ref) => FirestoreService(ref.watch(firestoreProvider)));

// --- App Data Providers ---
// Fetches the active event. Uses FutureProvider as event data is fetched once at app start.
final activeEventProvider = FutureProvider<DocumentSnapshot>((ref) async {
  return ref.watch(firestoreServiceProvider).getActiveEvent();
});

// Provides a stream of the currently logged-in user's profile data.
final userProfileProvider = StreamProvider.autoDispose<DocumentSnapshot? >((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final service = ref.watch(firestoreServiceProvider);
  if (auth.currentUser != null) {
    return service.getUserProfileStream(auth.currentUser!.uid);
  }
  return Stream.value(null); // Return empty stream if no user is logged in
});

// Provides a stream of all sessions for the active event, ordered by start time.
final sessionsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final eventAsync = ref.watch(activeEventProvider);
  final service = ref.watch(firestoreServiceProvider);
  final eventId = eventAsync.asData?.value.id; // Safely get event ID from FutureProvider
  if (eventId != null) {
    return service.getSessionsStream(eventId);
  }
  return const Stream.empty(); // Return empty stream if no active event is found
});

// Provides a stream of all sponsors for the active event.
final sponsorsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final eventAsync = ref.watch(activeEventProvider);
  final service = ref.watch(firestoreServiceProvider);
  final eventId = eventAsync.asData?.value.id;
  if (eventId != null) {
    return service.getSponsorsStream(eventId);
  }
  return const Stream.empty();
});

// Fetches speaker details for a given list of speaker UIDs.
// Uses FutureProvider.family to allow passing parameters (speakerIds) to the provider.
final sessionSpeakersProvider =
    FutureProvider.family<List<DocumentSnapshot>, List<String>>(
        (ref, speakerIds) async {
  if (speakerIds.isEmpty) return [];
  return ref.watch(firestoreServiceProvider).getUsersByIds(speakerIds);
});