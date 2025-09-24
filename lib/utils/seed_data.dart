import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SeedData {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Main method to seed all data
  static Future<void> seedAllData() async {
    debugPrint('🌱 Starting data seeding...');
    
    // Clear existing data first (optional)
    await _clearExistingData();
    
    // Seed in order due to dependencies
    final eventId = await _seedEvents();
    await _seedSponsors(eventId);
    await _seedSessions(eventId);
    await _seedUsers();
    
    debugPrint('🌱 Data seeding completed successfully!');
  }

  /// Clear existing data (optional - be careful in production!)
  static Future<void> _clearExistingData() async {
    debugPrint('🧹 Clearing existing data...');
    
    // Clear collections
    await _clearCollection('events');
    await _clearCollection('sponsors');
    await _clearCollection('sessions');
    await _clearCollection('users');
  }

  static Future<void> _clearCollection(String collectionName) async {
    final batch = _db.batch();
    final snapshot = await _db.collection(collectionName).get();
    
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    debugPrint('🧹 Cleared $collectionName collection');
  }

  /// Seed events data
  static Future<String> _seedEvents() async {
    debugPrint('🎯 Seeding events...');
    
    final eventRef = _db.collection('events').doc();
    await eventRef.set({
      'name': 'Flutter Connect 2024',
      'description': 'The premier Flutter conference bringing together developers, designers, and innovators.',
      'location': 'San Francisco, CA',
      'startDate': Timestamp.fromDate(DateTime(2024, 11, 15)),
      'endDate': Timestamp.fromDate(DateTime(2024, 11, 17)),
      'isActive': true,
      'website': 'https://flutterconnect.dev',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    debugPrint('✅ Events seeded');
    return eventRef.id;
  }

  /// Seed sponsors data
  static Future<void> _seedSponsors(String eventId) async {
    debugPrint('🏢 Seeding sponsors...');
    
    final sponsors = [
      {
        'eventId': eventId,
        'name': 'Google',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/2/2f/Google_2015_logo.svg',
        'website': 'https://developers.google.com/flutter',
        'description': 'Flutter is made by Google',
        'tier': 'platinum',
      },
      {
        'eventId': eventId,
        'name': 'Microsoft',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/9/96/Microsoft_logo_%282012%29.svg',
        'website': 'https://microsoft.com',
        'description': 'Cloud and enterprise solutions',
        'tier': 'gold',
      },
      {
        'eventId': eventId,
        'name': 'AWS',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/9/93/Amazon_Web_Services_Logo.svg',
        'website': 'https://aws.amazon.com',
        'description': 'Cloud computing platform',
        'tier': 'gold',
      },
      {
        'eventId': eventId,
        'name': 'Firebase',
        'logoUrl': 'https://firebase.google.com/images/brand-guidelines/logo-logomark.png',
        'website': 'https://firebase.google.com',
        'description': 'Backend-as-a-Service platform',
        'tier': 'silver',
      },
    ];

    final batch = _db.batch();
    for (var sponsor in sponsors) {
      final ref = _db.collection('sponsors').doc();
      batch.set(ref, {
        ...sponsor,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('✅ Sponsors seeded');
  }

  /// Seed sessions data
  static Future<void> _seedSessions(String eventId) async {
    debugPrint('📅 Seeding sessions...');
    
    final sessions = [
      {
        'eventId': eventId,
        'title': 'Flutter State Management Deep Dive',
        'description': 'Exploring Riverpod, Bloc, and Provider patterns for scalable Flutter apps.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 15, 9, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 15, 10, 0)),
        'location': 'Main Hall',
        'speakerIds': ['speaker1', 'speaker2'],
        'type': 'talk',
        'tags': ['state-management', 'architecture'],
      },
      {
        'eventId': eventId,
        'title': 'Building Responsive UIs with Flutter',
        'description': 'Learn how to create beautiful, responsive interfaces that work across all devices.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 15, 10, 30)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 15, 11, 30)),
        'location': 'Room A',
        'speakerIds': ['speaker3'],
        'type': 'workshop',
        'tags': ['ui', 'responsive', 'design'],
      },
      {
        'eventId': eventId,
        'title': 'Flutter Performance Optimization',
        'description': 'Tips and tricks to make your Flutter apps lightning fast.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 15, 14, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 15, 15, 0)),
        'location': 'Main Hall',
        'speakerIds': ['speaker4'],
        'type': 'talk',
        'tags': ['performance', 'optimization'],
      },
    ];

    final batch = _db.batch();
    for (var session in sessions) {
      final ref = _db.collection('sessions').doc();
      batch.set(ref, {
        ...session,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('✅ Sessions seeded');
  }

  /// Seed users data (speakers)
  static Future<void> _seedUsers() async {
    debugPrint('👥 Seeding users...');
    
    final users = [
      {
        'uid': 'speaker1',
        'name': 'Sarah Johnson',
        'email': 'sarah@example.com',
        'bio': 'Flutter GDE and mobile architect with 8+ years of experience.',
        'company': 'Tech Corp',
        'role': 'Senior Flutter Developer',
        'profileImageUrl': 'https://images.unsplash.com/photo-1494790108755-2616b612b602?w=400',
        'socialLinks': {
          'twitter': 'https://twitter.com/sarahflutter',
          'linkedin': 'https://linkedin.com/in/sarahjohnson',
        },
      },
      {
        'uid': 'speaker2',
        'name': 'Alex Chen',
        'email': 'alex@example.com',
        'bio': 'State management expert and open source contributor.',
        'company': 'Flutter Solutions',
        'role': 'Technical Lead',
        'profileImageUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
        'socialLinks': {
          'twitter': 'https://twitter.com/alexchen',
          'github': 'https://github.com/alexchen',
        },
      },
      {
        'uid': 'speaker3',
        'name': 'Maya Patel',
        'email': 'maya@example.com',
        'bio': 'UI/UX designer turned Flutter developer, passionate about beautiful interfaces.',
        'company': 'Design Studio',
        'role': 'Flutter Designer',
        'profileImageUrl': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400',
        'socialLinks': {
          'dribbble': 'https://dribbble.com/mayapatel',
          'linkedin': 'https://linkedin.com/in/mayapatel',
        },
      },
      {
        'uid': 'speaker4',
        'name': 'David Kim',
        'email': 'david@example.com',
        'bio': 'Performance optimization specialist and Flutter team member.',
        'company': 'Google',
        'role': 'Flutter Engineer',
        'profileImageUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400',
        'socialLinks': {
          'twitter': 'https://twitter.com/davidkim',
          'medium': 'https://medium.com/@davidkim',
        },
      },
    ];

    final batch = _db.batch();
    for (var user in users) {
      final ref = _db.collection('users').doc(user['uid'] as String);
      batch.set(ref, {
        ...user,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('✅ Users seeded');
  }
}