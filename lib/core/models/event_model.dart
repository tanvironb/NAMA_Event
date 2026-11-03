import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final bool isActive;
  final String venueMapUrl;

  /// Locations configured by the admin for meeting requests.
  ///
  /// Existing events without this field use an empty list.
  final List<String> meetingLocations;

  Event({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.isActive,
    required this.venueMapUrl,
    this.meetingLocations = const [],
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Missing data for event ${doc.id}');
    }

    return Event(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Event',
      description: data['description'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      location: data['location'] as String? ?? 'Unknown Location',
      isActive: data['isActive'] as bool? ?? false,
      venueMapUrl: data['venueMapUrl'] as String? ?? '',
      meetingLocations: _readMeetingLocations(
        data['meetingLocations'],
      ),
    );
  }

  static List<String> _readMeetingLocations(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final locations = <String>[];
    final seen = <String>{};

    for (final item in value) {
      if (item is! String) continue;

      final location = item.trim();

      if (location.isEmpty) continue;

      if (seen.add(location.toLowerCase())) {
        locations.add(location);
      }
    }

    return List<String>.unmodifiable(locations);
  }
}