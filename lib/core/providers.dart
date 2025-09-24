import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

// Firebase Providers
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// Auth State Provider
final authStateChangesProvider = StreamProvider<User?>(
    (ref) => ref.watch(firebaseAuthProvider).authStateChanges());

// Service Provider
final firestoreServiceProvider = Provider<FirestoreService>(
    (ref) => FirestoreService(ref.watch(firestoreProvider)));

// App Data Providers
final activeEventProvider =
    FutureProvider((ref) => ref.watch(firestoreServiceProvider).getActiveEvent());

final userProfileProvider = StreamProvider.autoDispose((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final service = ref.watch(firestoreServiceProvider);
  if (auth.currentUser != null) {
    return service.getUserProfileStream(auth.currentUser!.uid);
  }
  return Stream.value(null);
});

final sessionsStreamProvider = StreamProvider.autoDispose((ref) {
  final eventAsync = ref.watch(activeEventProvider);
  final service = ref.watch(firestoreServiceProvider);
  final eventId = eventAsync.asData?.value.id;
  if (eventId != null) {
    return service.getSessionsStream(eventId);
  }
  return const Stream.empty();
});

final sponsorsStreamProvider = StreamProvider.autoDispose((ref) {
  final eventAsync = ref.watch(activeEventProvider);
  final service = ref.watch(firestoreServiceProvider);
  final eventId = eventAsync.asData?.value.id;
  if (eventId != null) {
    return service.getSponsorsStream(eventId);
  }
  return const Stream.empty();
});

final sessionSpeakersProvider =
    FutureProvider.family<List<DocumentSnapshot>, List<String>>(
        (ref, speakerIds) async {
  if (speakerIds.isEmpty) return [];
  return ref.watch(firestoreServiceProvider).getUsersByIds(speakerIds);
});