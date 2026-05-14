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
  final String category;
  final String imageUrl;

  final int priority;
  final String partnerId;
  final bool isChatEnabled;
  final String closedBy;
  final List<String> checkedInAttendees;
  final int totalMessages;
  final List<String> uniqueParticipants;
  final List<String> mutedUsers;

  final DateTime? firstMessageAt;
  final DateTime? lastMessageAt;
  final int deletedMessagesCount;
  final Map<String, int> messagesByRole;
  final List<String> muteHistory;
  final int totalMuteActions;

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
    this.imageUrl = '',
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
      imageUrl: data['imageUrl'] as String? ?? '',
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

  bool get hasEnded => DateTime.now().isAfter(endTime);

  bool get isWithinGracePeriod {
    if (!hasEnded) return false;
    final gracePeriodEnd = endTime.add(const Duration(minutes: 35));
    return DateTime.now().isBefore(gracePeriodEnd);
  }

  bool get isActive =>
      DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime);

  bool get isChatAvailable => isChatEnabled && !hasEnded;

  bool get isAdminLocked => !isChatEnabled && closedBy == 'admin';

  bool isUserMuted(String userId) => mutedUsers.contains(userId);

  bool canSpeakerSendAfterEnd(String userId) {
    return speakerIds.contains(userId) && isWithinGracePeriod;
  }

  double get averageMessagesPerParticipant {
    if (uniqueParticipants.isEmpty) return 0.0;
    return totalMessages / uniqueParticipants.length;
  }

  int get chatDurationMinutes {
    if (firstMessageAt == null || lastMessageAt == null) return 0;
    return lastMessageAt!.difference(firstMessageAt!).inMinutes;
  }

  double get engagementRate {
    if (checkedInAttendees.isEmpty) return 0.0;
    return (uniqueParticipants.length / checkedInAttendees.length) * 100;
  }
}