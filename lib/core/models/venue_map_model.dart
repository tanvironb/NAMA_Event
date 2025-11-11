import 'package:cloud_firestore/cloud_firestore.dart';

/// Venue Map Model - Represents a venue map with multiple images
/// Each event can have multiple venue maps (e.g., different floors, areas)
class VenueMap {
  final String id;
  final String title;
  final String description;
  final String floor;
  final List<String> imageUrls; // Array of image URLs for this map location
  final int order; // Display order

  VenueMap({
    required this.id,
    required this.title,
    required this.description,
    required this.floor,
    required this.imageUrls,
    required this.order,
  });

  factory VenueMap.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing data for venue map ${doc.id}');
    }
    return VenueMap(
      id: doc.id,
      title: data['title'] as String? ?? 'Unnamed Map',
      description: data['description'] as String? ?? '',
      floor: data['floor'] as String? ?? '',
      imageUrls: (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'floor': floor,
      'imageUrls': imageUrls,
      'order': order,
    };
  }
}
