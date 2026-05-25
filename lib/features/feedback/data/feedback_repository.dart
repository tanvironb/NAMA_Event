import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_feedback_model.dart';

class FeedbackRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit feedback for a session.
  ///
  /// IMPORTANT:
  /// - Uses userId as feedback document ID to prevent duplicate feedback.
  /// - Updates session feedback counters in the same transaction.
  /// - If old feedback already exists, it repairs feedback status and session counters.
  Future<void> submitFeedback({
    required String sessionId,
    required String userId,
    required String userName,
    required bool isAnonymous,
    required int rating,
    required String comment,
    required String userRole,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    final feedbackRef = sessionRef.collection('feedback').doc(userId);

    final statusRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('feedbackStatus')
        .doc(sessionId);

    await _firestore.runTransaction((transaction) async {
      final sessionDoc = await transaction.get(sessionRef);
      final existingFeedbackDoc = await transaction.get(feedbackRef);

      if (!sessionDoc.exists) {
        throw Exception('session_not_found');
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>? ?? {};

      // If feedback already exists, repair status + session analytics only.
      if (existingFeedbackDoc.exists) {
        final existingData =
            existingFeedbackDoc.data() as Map<String, dynamic>? ?? {};

        final existingRating = (existingData['rating'] as num?)?.toInt() ?? 0;

        transaction.set(
          statusRef,
          {
            'userId': userId,
            'sessionId': sessionId,
            'hasSubmitted': true,
            'hasDismissed': false,
            'submittedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Recalculate from all feedback after this old one.
        // This is a safe repair path for old records.
        final totalFeedbacks = (sessionData['totalFeedbacks'] as int? ?? 0);
        final totalRating = (sessionData['totalRating'] as int? ?? 0);

        if (totalFeedbacks == 0 && existingRating > 0) {
          transaction.update(sessionRef, {
            'totalFeedbacks': 1,
            'totalRating': existingRating,
            'averageRating': existingRating.toDouble(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return;
      }

      final oldTotalFeedbacks = (sessionData['totalFeedbacks'] as int? ?? 0);
      final oldTotalRating = (sessionData['totalRating'] as int? ?? 0);

      final newTotalFeedbacks = oldTotalFeedbacks + 1;
      final newTotalRating = oldTotalRating + rating;
      final newAverageRating = newTotalRating / newTotalFeedbacks;

      transaction.set(feedbackRef, {
        'sessionId': sessionId,
        'userId': userId,
        'userName': isAnonymous ? 'Anonymous' : userName,
        'isAnonymous': isAnonymous,
        'rating': rating,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
        'userRole': userRole,
      });

      transaction.set(
        statusRef,
        {
          'userId': userId,
          'sessionId': sessionId,
          'hasSubmitted': true,
          'hasDismissed': false,
          'submittedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.update(sessionRef, {
        'totalFeedbacks': newTotalFeedbacks,
        'totalRating': newTotalRating,
        'averageRating': newAverageRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Mark feedback as dismissed.
  Future<void> dismissFeedback({
    required String userId,
    required String sessionId,
  }) async {
    await _updateFeedbackStatus(
      userId: userId,
      sessionId: sessionId,
      hasSubmitted: false,
      hasDismissed: true,
    );
  }

  Future<void> _updateFeedbackStatus({
    required String userId,
    required String sessionId,
    required bool hasSubmitted,
    required bool hasDismissed,
  }) async {
    final statusRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('feedbackStatus')
        .doc(sessionId);

    final Map<String, dynamic> data = {
      'userId': userId,
      'sessionId': sessionId,
      'hasSubmitted': hasSubmitted,
      'hasDismissed': hasDismissed,
    };

    if (hasSubmitted) {
      data['submittedAt'] = FieldValue.serverTimestamp();
    }

    if (hasDismissed) {
      data['dismissedAt'] = FieldValue.serverTimestamp();
    }

    await statusRef.set(data, SetOptions(merge: true));
  }

  /// Repairs one session's feedback counters from the feedback subcollection.
  ///
  /// Use this when old feedback documents exist but session.totalFeedbacks
  /// and session.averageRating are wrong.
  Future<void> repairSessionFeedbackAnalytics(String sessionId) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    final feedbackSnapshot = await sessionRef.collection('feedback').get();

    int totalFeedbacks = 0;
    int totalRating = 0;

    for (final doc in feedbackSnapshot.docs) {
      final data = doc.data();
      final rating = (data['rating'] as num?)?.toInt() ?? 0;

      if (rating > 0) {
        totalFeedbacks++;
        totalRating += rating;
      }
    }

    final averageRating =
        totalFeedbacks > 0 ? totalRating / totalFeedbacks : 0.0;

    await sessionRef.update({
      'totalFeedbacks': totalFeedbacks,
      'totalRating': totalRating,
      'averageRating': averageRating,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<FeedbackStatus> getFeedbackStatus({
    required String userId,
    required String sessionId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('feedbackStatus')
        .doc(sessionId)
        .get();

    if (!doc.exists) {
      return FeedbackStatus(
        userId: userId,
        sessionId: sessionId,
        hasSubmitted: false,
        hasDismissed: false,
      );
    }

    return FeedbackStatus.fromFirestore(doc);
  }

  Stream<FeedbackStatus> feedbackStatusStream({
    required String userId,
    required String sessionId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('feedbackStatus')
        .doc(sessionId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return FeedbackStatus(
          userId: userId,
          sessionId: sessionId,
          hasSubmitted: false,
          hasDismissed: false,
        );
      }

      return FeedbackStatus.fromFirestore(doc);
    });
  }

  Stream<List<SessionFeedback>> getSessionFeedbackStream(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('feedback')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SessionFeedback.fromFirestore(doc))
          .toList();
    });
  }

  Future<int> getFeedbackCount(String sessionId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('feedback')
        .count()
        .get();

    return snapshot.count ?? 0;
  }
}