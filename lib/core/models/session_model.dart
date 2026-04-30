import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String eventId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final List<String> speakerIds;
  final String liveStreamUrl;
  final String qrCodePayload;

  /// Used for homepage filters:
  /// Education, Ai, Social, Scholarship, etc.
  final String category;

  /// Priority rating for live stream sessions (1-5 scale)
  /// 1 = Low priority (optional breakout sessions)
  /// 2 = Below normal (specialized workshops)
  /// 3 = Normal priority (regular talks)
  /// 4 = High priority (featured speakers, important announcements)
  /// 5 = Maximum priority (keynotes, urgent updates, main event streams)
  final int priority;

  final String partnerId;
  final bool isChatEnabled;
  final String closedBy;
  final List<String> checkedInAttendees;
  final int totalMessages;
  final List<String> uniqueParticipants;
  final List<String> mutedUsers;

  // Enhanced Analytics Fields
  final DateTime? firstMessageAt;
  final DateTime? lastMessageAt;
  final int deletedMessagesCount;
  final Map<String, int> messagesByRole;
  final List<String> muteHistory;
  final int totalMuteActions;

  // Feedback Analytics Fields
  final int totalFeedbacks;
  final int totalRating;
  final double averageRating;

  Session({
    required this.id,
    required this.eventId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.speakerIds,
    this.liveStreamUrl = '',
    this.qrCodePayload = '',
    this.category = '',
    this.priority = 3,
    this.partnerId = '',
    this.isChatEnabled = true,
    this.closedBy = '',
    this.checkedInAttendees = const [],
    this.totalMessages = 0,
    this.uniqueParticipants = const [],
    this.mutedUsers = const [],
    this.firstMessageAt,
    this.lastMessageAt,
    this.deletedMessagesCount = 0,
    this.messagesByRole = const {},
    this.muteHistory = const [],
    this.totalMuteActions = 0,
    this.totalFeedbacks = 0,
    this.totalRating = 0,
    this.averageRating = 0.0,
  });

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Missing data for session ${doc.id}');
    }

    return Session(
      id: doc.id,
      eventId: data['eventId'] as String,
      title: data['title'] as String? ?? 'Untitled Session',
      description: data['description'] as String? ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      location: data['location'] as String? ?? 'Unknown Room',
      speakerIds: List<String>.from(data['speakerIds'] as List? ?? []),
      liveStreamUrl: data['liveStreamUrl'] as String? ?? '',
      qrCodePayload: data['qrCodePayload'] as String? ?? '',
      category: data['category'] as String? ?? '',
      priority: data['priority'] as int? ?? 3,
      partnerId: data['partnerId'] as String? ?? '',
      isChatEnabled: data['isChatEnabled'] as bool? ?? true,
      closedBy: data['closedBy'] as String? ?? '',
      checkedInAttendees:
          List<String>.from(data['checkedInAttendees'] as List? ?? []),
      totalMessages: data['totalMessages'] as int? ?? 0,
      uniqueParticipants:
          List<String>.from(data['uniqueParticipants'] as List? ?? []),
      mutedUsers: List<String>.from(data['mutedUsers'] as List? ?? []),
      firstMessageAt: data['firstMessageAt'] != null
          ? (data['firstMessageAt'] as Timestamp).toDate()
          : null,
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      deletedMessagesCount: data['deletedMessagesCount'] as int? ?? 0,
      messagesByRole:
          Map<String, int>.from(data['messagesByRole'] as Map? ?? {}),
      muteHistory: List<String>.from(data['muteHistory'] as List? ?? []),
      totalMuteActions: data['totalMuteActions'] as int? ?? 0,
      totalFeedbacks: data['totalFeedbacks'] as int? ?? 0,
      totalRating: data['totalRating'] as int? ?? 0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Check if the session has ended (based on end time)
  bool get hasEnded => DateTime.now().isAfter(endTime);

  /// Check if we're within 35 minutes after session ended (grace period for speakers)
  bool get isWithinGracePeriod {
    if (!hasEnded) return false;
    final gracePeriodEnd = endTime.add(const Duration(minutes: 35));
    return DateTime.now().isBefore(gracePeriodEnd);
  }

  /// Check if the session is currently active (between start and end time)
  bool get isActive =>
      DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime);

  /// Check if chat is available (enabled and session hasn't ended)
  bool get isChatAvailable => isChatEnabled && !hasEnded;

  /// Check if chat was closed by admin (admin lock takes precedence)
  bool get isAdminLocked => !isChatEnabled && closedBy == 'admin';

  /// Check if user is muted in this session
  bool isUserMuted(String userId) => mutedUsers.contains(userId);

  /// Check if a speaker can still send messages (within grace period)
  bool canSpeakerSendAfterEnd(String userId) {
    return speakerIds.contains(userId) && isWithinGracePeriod;
  }

  /// Calculate average messages per participant
  double get averageMessagesPerParticipant {
    if (uniqueParticipants.isEmpty) return 0.0;
    return totalMessages / uniqueParticipants.length;
  }

  /// Calculate chat duration in minutes
  int get chatDurationMinutes {
    if (firstMessageAt == null || lastMessageAt == null) return 0;
    return lastMessageAt!.difference(firstMessageAt!).inMinutes;
  }

  /// Get engagement rate (unique participants / checked in attendees)
  double get engagementRate {
    if (checkedInAttendees.isEmpty) return 0.0;
    return (uniqueParticipants.length / checkedInAttendees.length) * 100;
  }
}