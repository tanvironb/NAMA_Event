import 'package:cloud_firestore/cloud_firestore.dart';

class Sponsor {
  final String id;
  final String eventId;
  final String name;
  final String logoUrl;
  final String website;
  final String description;

  Sponsor({
    required this.id,
    required this.eventId,
    required this.name,
    required this.logoUrl,
    this.website = '',
    this.description = '',
  });

  factory Sponsor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing data for sponsor ${doc.id}');
    }
    return Sponsor(
      id: doc.id,
      eventId: data['eventId'] as String,
      name: data['name'] as String? ?? 'Unnamed Sponsor',
      logoUrl: data['logoUrl'] as String? ?? '',
      website: data['website'] as String? ?? '',
      description: data['description'] as String? ?? '',
    );
  }
}