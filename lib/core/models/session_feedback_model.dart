import 'package:cloud_firestore/cloud_firestore.dart';

class SessionFeedback {
  final String id;
  final String sessionId;
  final String userId; // Always stored for duplicate prevention
  final String userName; // Shown as "Anonymous" if isAnonymous is true
  final bool isAnonymous;
  final int rating; // 1-5 stars
  final String comment;
  final DateTime timestamp;
  final String userRole; // For analytics (attendee, speaker, staff)

  SessionFeedback({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.userName,
    required this.isAnonymous,
    required this.rating,
    required this.comment,
    required this.timestamp,
    required this.userRole,
  });

  factory SessionFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing data for feedback ${doc.id}');
    }
    
    return SessionFeedback(
      id: doc.id,
      sessionId: data['sessionId'] as String,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      rating: data['rating'] as int,
      comment: data['comment'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      userRole: data['userRole'] as String? ?? 'attendee',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'userName': userName,
      'isAnonymous': isAnonymous,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
      'userRole': userRole,
    };
  }

  /// Get display name (shows "Anonymous" if isAnonymous is true)
  String get displayName => isAnonymous ? 'Anonymous' : userName;
}

/// Tracks user's feedback status for a session
class FeedbackStatus {
  final String userId;
  final String sessionId;
  final bool hasSubmitted;
  final bool hasDismissed;
  final DateTime? submittedAt;
  final DateTime? dismissedAt;

  FeedbackStatus({
    required this.userId,
    required this.sessionId,
    required this.hasSubmitted,
    required this.hasDismissed,
    this.submittedAt,
    this.dismissedAt,
  });

  factory FeedbackStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return FeedbackStatus(
        userId: '',
        sessionId: '',
        hasSubmitted: false,
        hasDismissed: false,
      );
    }
    
    return FeedbackStatus(
      userId: data['userId'] as String? ?? '',
      sessionId: data['sessionId'] as String? ?? '',
      hasSubmitted: data['hasSubmitted'] as bool? ?? false,
      hasDismissed: data['hasDismissed'] as bool? ?? false,
      submittedAt: data['submittedAt'] != null 
          ? (data['submittedAt'] as Timestamp).toDate() 
          : null,
      dismissedAt: data['dismissedAt'] != null 
          ? (data['dismissedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'sessionId': sessionId,
      'hasSubmitted': hasSubmitted,
      'hasDismissed': hasDismissed,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'dismissedAt': dismissedAt != null ? Timestamp.fromDate(dismissedAt!) : null,
    };
  }

  /// Check if feedback prompt should be shown
  bool get shouldShowPrompt => !hasSubmitted && !hasDismissed;
}
