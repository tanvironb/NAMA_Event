import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class AgendaRepository {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;

  AgendaRepository(
    this._firestoreService, {
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  // Provides sessions for the selected event.
  Stream<List<Session>> getSessionsStream(String eventId) {
    return _firestoreService
        .getSessionsCollectionStream(eventId)
        .map((snapshot) {
      return snapshot.docs
          .map((document) => Session.fromFirestore(document))
          .toList();
    });
  }

  // Fetches sessions associated with a partner.
  Future<List<Session>> getSessionsByPartnerId(
    String partnerId,
  ) async {
    final snapshot =
        await _firestoreService.getSessionsByPartnerId(partnerId);

    return snapshot.docs
        .map((document) => Session.fromFirestore(document))
        .toList();
  }

  // Returns true when bookmarked, false when unbookmarked.
  Future<bool> toggleBookmark(String sessionId) {
    return _updateBookmark(sessionId);
  }

  // Sets an explicit bookmark state.
  // An existing bookmark keeps its original recorded time.
  Future<bool> setBookmarked(
    String sessionId,
    bool bookmarked,
  ) {
    return _updateBookmark(
      sessionId,
      desiredState: bookmarked,
    );
  }

  Future<bool> _updateBookmark(
    String sessionId, {
    bool? desiredState,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Sign in to bookmark a session.');
    }

    if (sessionId.trim().isEmpty) {
      throw ArgumentError('A session ID is required.');
    }

    final sessionRef = _db.collection('sessions').doc(sessionId);

    return _db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(sessionRef);

      if (!snapshot.exists) {
        throw StateError('This session no longer exists.');
      }

      final data = snapshot.data()!;
      final existing = data['bookmarkedBy'];

      final alreadyBookmarked =
          existing is List && existing.contains(user.uid);

      final shouldBookmark =
          desiredState ?? !alreadyBookmarked;

      if (shouldBookmark == alreadyBookmarked) {
        return shouldBookmark;
      }

      // Transaction.update requires String map keys.
      transaction.update(sessionRef, <String, dynamic>{
        'bookmarkedBy': shouldBookmark
            ? FieldValue.arrayUnion([user.uid])
            : FieldValue.arrayRemove([user.uid]),
        'bookmarkTimes.${user.uid}': shouldBookmark
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      });

      return shouldBookmark;
    });
  }
}