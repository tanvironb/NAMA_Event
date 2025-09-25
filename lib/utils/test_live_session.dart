import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TestLiveSession {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Add a test live session that's currently active with a YouTube URL
  static Future<void> addTestLiveSession() async {
    debugPrint('🎥 Adding test live session...');
    
    try {
      // First, get the active event
      final eventsSnapshot = await _db.collection('events').limit(1).get();
      if (eventsSnapshot.docs.isEmpty) {
        debugPrint('❌ No events found. Please seed events first.');
        return;
      }
      
      final eventId = eventsSnapshot.docs.first.id;
      
      // Create a session that's currently active (started 30 minutes ago, ends in 30 minutes)
      final testSession = {
        'eventId': eventId,
        'title': 'Live Demo: Building Real-time Apps',
        'description': 'Watch as we build a real-time Flutter app with Firebase.',
        'startTime': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 30))),
        'endTime': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 30))),
        'location': 'Online Stream',
        'speakerIds': ['live-speaker'],
        'type': 'live-demo',
        'tags': ['live', 'demo', 'real-time'],
        'liveStreamUrl': 'https://www.youtube.com/watch?v=jfKfPfyJRdk', // Test YouTube URL
        'priority': 4, // High priority - featured demo session
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('sessions').add(testSession);
      debugPrint('✅ Test live session added successfully!');
      debugPrint('🎥 Session: ${testSession['title']}');
      debugPrint('🔗 YouTube URL: ${testSession['liveStreamUrl']}');
      debugPrint('🔥 Priority: ${testSession['priority']} (4 = High Priority)');
      debugPrint('⏰ Active from ${testSession['startTime']} to ${testSession['endTime']}');
      
    } catch (e) {
      debugPrint('❌ Error adding test live session: $e');
    }
  }

  /// Add multiple test live sessions with different priorities to test priority selection
  static Future<void> addMultipleTestSessions() async {
    debugPrint('🎥 Adding multiple test live sessions with different priorities...');
    
    try {
      // First, get the active event
      final eventsSnapshot = await _db.collection('events').limit(1).get();
      if (eventsSnapshot.docs.isEmpty) {
        debugPrint('❌ No events found. Please seed events first.');
        return;
      }
      
      final eventId = eventsSnapshot.docs.first.id;
      final now = DateTime.now();
      
      // Create multiple test sessions with different priorities
      final testSessions = [
        {
          'eventId': eventId,
          'title': '🎯 KEYNOTE: Flutter\'s Future',
          'description': 'The most important session - Flutter team announcing major updates.',
          'startTime': Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
          'endTime': Timestamp.fromDate(now.add(const Duration(minutes: 45))),
          'location': 'Main Hall',
          'speakerIds': ['keynote-speaker'],
          'type': 'keynote',
          'tags': ['keynote', 'announcement'],
          'liveStreamUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'priority': 5, // Maximum priority - KEYNOTE
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'eventId': eventId,
          'title': '📱 Building Flutter Apps',
          'description': 'Regular workshop on Flutter development basics.',
          'startTime': Timestamp.fromDate(now.subtract(const Duration(minutes: 20))),
          'endTime': Timestamp.fromDate(now.add(const Duration(minutes: 40))),
          'location': 'Room A',
          'speakerIds': ['workshop-speaker'],
          'type': 'workshop',
          'tags': ['workshop', 'basics'],
          'liveStreamUrl': 'https://www.youtube.com/watch?v=jfKfPfyJRdk',
          'priority': 3, // Normal priority - regular workshop
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'eventId': eventId,
          'title': '🛠️ Advanced Debugging',
          'description': 'Specialized breakout session for advanced developers.',
          'startTime': Timestamp.fromDate(now.subtract(const Duration(minutes: 10))),
          'endTime': Timestamp.fromDate(now.add(const Duration(minutes: 50))),
          'location': 'Room B',
          'speakerIds': ['debug-speaker'],
          'type': 'breakout',
          'tags': ['debugging', 'advanced'],
          'liveStreamUrl': 'https://www.youtube.com/watch?v=fC7oUOUEEi4',
          'priority': 2, // Below normal - specialized session
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      final batch = _db.batch();
      for (var session in testSessions) {
        final ref = _db.collection('sessions').doc();
        batch.set(ref, session);
      }
      
      await batch.commit();
      debugPrint('✅ Multiple test sessions added successfully!');
      debugPrint('🎯 Expected selection: KEYNOTE (Priority 5) should be shown in YouTube player');
      for (var session in testSessions) {
        debugPrint('   - ${session['title']} (Priority: ${session['priority']})');
      }
      
    } catch (e) {
      debugPrint('❌ Error adding multiple test sessions: $e');
    }
  }

  /// Remove test live session
  static Future<void> removeTestLiveSession() async {
    debugPrint('🧹 Removing test live session...');
    
    try {
      final snapshot = await _db.collection('sessions')
          .where('title', isEqualTo: 'Live Demo: Building Real-time Apps')
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      debugPrint('✅ Test live session removed');
    } catch (e) {
      debugPrint('❌ Error removing test live session: $e');
    }
  }

  /// Remove all test sessions
  static Future<void> removeAllTestSessions() async {
    debugPrint('🧹 Removing all test sessions...');
    
    try {
      final testTitles = [
        'Live Demo: Building Real-time Apps',
        '🎯 KEYNOTE: Flutter\'s Future',  
        '📱 Building Flutter Apps',
        '🛠️ Advanced Debugging',
      ];
      
      final batch = _db.batch();
      for (var title in testTitles) {
        final snapshot = await _db.collection('sessions')
            .where('title', isEqualTo: title)
            .get();
        
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
      }
      
      await batch.commit();
      debugPrint('✅ All test sessions removed');
    } catch (e) {
      debugPrint('❌ Error removing test sessions: $e');
    }
  }
}