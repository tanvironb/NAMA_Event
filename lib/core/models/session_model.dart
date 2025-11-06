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
  final String qrCodePayload; // NEW
  /// Priority rating for live stream sessions (1-5 scale)
  /// 1 = Low priority (optional breakout sessions)
  /// 2 = Below normal (specialized workshops)
  /// 3 = Normal priority (regular talks)
  /// 4 = High priority (featured speakers, important announcements)
  /// 5 = Maximum priority (keynotes, urgent updates, main event streams)
  final int priority;
  final String partnerId; // NEW (Optional): Links session to a sponsor for bulk-bookmarking
  final bool isChatEnabled; // Whether chat is currently enabled (can be closed by speaker/admin)
  final String closedBy; // Who closed the chat: 'speaker' or 'admin' or '' (empty if open)
  final List<String> checkedInAttendees; // List of attendee UIDs who checked in via QR
  final int totalMessages; // Total message count for analytics
  final List<String> uniqueParticipants; // List of unique user IDs who sent messages
  final List<String> mutedUsers; // List of user IDs who are muted in this session
  
  // Enhanced Analytics Fields
  final DateTime? firstMessageAt; // When the first message was sent
  final DateTime? lastMessageAt; // When the most recent message was sent
  final int deletedMessagesCount; // Number of deleted messages (for moderation tracking)
  final Map<String, int> messagesByRole; // Count of messages by role (attendee, speaker, admin, staff)
  final List<String> muteHistory; // Track users who were muted (for analytics)
  final int totalMuteActions; // Total number of mute actions performed


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
    this.qrCodePayload = '', // NEW
    this.priority = 3, // Default to normal priority
    this.partnerId = '', // NEW (Optional): Links session to a sponsor for bulk-bookmarking
    this.isChatEnabled = true, // Chat enabled by default
    this.closedBy = '', // Empty means chat is open
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
      qrCodePayload: data['qrCodePayload'] as String? ?? '', // NEW
      priority: data['priority'] as int? ?? 3, // Default to normal priority if not specified
      partnerId: data['partnerId'] as String? ?? '', // NEW (Optional): Links session to a sponsor for bulk-bookmarking
      isChatEnabled: data['isChatEnabled'] as bool? ?? true,
      closedBy: data['closedBy'] as String? ?? '',
      checkedInAttendees: List<String>.from(data['checkedInAttendees'] as List? ?? []),
      totalMessages: data['totalMessages'] as int? ?? 0,
      uniqueParticipants: List<String>.from(data['uniqueParticipants'] as List? ?? []),
      mutedUsers: List<String>.from(data['mutedUsers'] as List? ?? []),
      firstMessageAt: data['firstMessageAt'] != null 
          ? (data['firstMessageAt'] as Timestamp).toDate() 
          : null,
      lastMessageAt: data['lastMessageAt'] != null 
          ? (data['lastMessageAt'] as Timestamp).toDate() 
          : null,
      deletedMessagesCount: data['deletedMessagesCount'] as int? ?? 0,
      messagesByRole: Map<String, int>.from(data['messagesByRole'] as Map? ?? {}),
      muteHistory: List<String>.from(data['muteHistory'] as List? ?? []),
      totalMuteActions: data['totalMuteActions'] as int? ?? 0,
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
  bool get isActive => DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime);

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