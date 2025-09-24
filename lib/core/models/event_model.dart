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

  Event({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.isActive,
    required this.venueMapUrl,
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
    );
  }
}