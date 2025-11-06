import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_feedback_model.dart';

class FeedbackRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit feedback for a session
  Future<void> submitFeedback({
    required String sessionId,
    required String userId,
    required String userName,
    required bool isAnonymous,
    required int rating,
    required String comment,
    required String userRole,
  }) async {
    final feedbackData = {
      'sessionId': sessionId,
      'userId': userId,
      'userName': isAnonymous ? 'Anonymous' : userName,
      'isAnonymous': isAnonymous,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
      'userRole': userRole,
    };

    // Add feedback to session's feedback subcollection
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('feedback')
        .add(feedbackData);

    // Update user's feedback status
    await _updateFeedbackStatus(
      userId: userId,
      sessionId: sessionId,
      hasSubmitted: true,
      hasDismissed: false,
    );

    // Update session analytics
    await _updateSessionFeedbackAnalytics(sessionId, rating);
  }

  /// Mark feedback as dismissed (user clicked X and confirmed)
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

  /// Update user's feedback status
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

    final data = {
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

  /// Update session feedback analytics
  Future<void> _updateSessionFeedbackAnalytics(String sessionId, int rating) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    await _firestore.runTransaction((transaction) async {
      final sessionDoc = await transaction.get(sessionRef);
      
      if (!sessionDoc.exists) return;
      
      final data = sessionDoc.data()!;
      final totalFeedbacks = (data['totalFeedbacks'] as int? ?? 0) + 1;
      final totalRating = (data['totalRating'] as int? ?? 0) + rating;
      final averageRating = totalRating / totalFeedbacks;

      transaction.update(sessionRef, {
        'totalFeedbacks': totalFeedbacks,
        'totalRating': totalRating,
        'averageRating': averageRating,
      });
    });
  }

  /// Get feedback status for a user and session
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

  /// Stream feedback status for a user and session
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

  /// Get all feedback for a session (for speakers/admins)
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

  /// Get feedback count for a session
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
