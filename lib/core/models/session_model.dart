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
  final bool isChatEnabled; // Whether chat is currently enabled (can be closed by speaker)
  final List<String> checkedInAttendees; // List of attendee UIDs who checked in via QR
  final int totalMessages; // Total message count for analytics
  final List<String> uniqueParticipants; // List of unique user IDs who sent messages


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
    this.checkedInAttendees = const [],
    this.totalMessages = 0,
    this.uniqueParticipants = const [],
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
      checkedInAttendees: List<String>.from(data['checkedInAttendees'] as List? ?? []),
      totalMessages: data['totalMessages'] as int? ?? 0,
      uniqueParticipants: List<String>.from(data['uniqueParticipants'] as List? ?? []),
    );
  }

  /// Check if the session has ended (based on end time)
  bool get hasEnded => DateTime.now().isAfter(endTime);

  /// Check if the session is currently active (between start and end time)
  bool get isActive => DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime);

  /// Check if chat is available (enabled and session hasn't ended)
  bool get isChatAvailable => isChatEnabled && !hasEnded;
}