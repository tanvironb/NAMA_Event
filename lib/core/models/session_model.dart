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
  /// Priority rating for live stream sessions (1-5 scale)
  /// 1 = Low priority (optional breakout sessions)
  /// 2 = Below normal (specialized workshops)
  /// 3 = Normal priority (regular talks)
  /// 4 = High priority (featured speakers, important announcements)
  /// 5 = Maximum priority (keynotes, urgent updates, main event streams)
  final int priority;

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
    this.priority = 3, // Default to normal priority
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
      priority: data['priority'] as int? ?? 3, // Default to normal priority if not specified
    );
  }
}