import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provides the Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// A simple provider to hold the active event ID.
// In a real app, you'd fetch this dynamically.
final activeEventIdProvider = Provider<String>((ref) => 'techconf_2025_kl');

// Provider to stream all sessions for the active event
final sessionsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final eventId = ref.watch(activeEventIdProvider);
  return firestore
      .collection('sessions')
      .where('eventId', isEqualTo: eventId)
      .orderBy('startTime')
      .snapshots();
});

// Provider to get the details of speakers for a given session
final sessionSpeakersProvider = FutureProvider.family<List<DocumentSnapshot>, List<String>>((ref, speakerIds) async {
  if (speakerIds.isEmpty) return [];
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore.collection('users').where(FieldPath.documentId, whereIn: speakerIds).get();
  return snapshot.docs;
});
