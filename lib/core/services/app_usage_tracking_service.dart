import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppUsageTrackingService {
  DateTime? _sessionStartTime;
  bool _isTimerRunning = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void startScreenTimer() {
    if (_isTimerRunning) return;

    _sessionStartTime = DateTime.now();
    _isTimerRunning = true;

    debugPrint('AppUsageTrackingService: Screen timer started.');
  }

  Future<void> stopScreenTimerAndSave({
    required String eventId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return;
    if (!_isTimerRunning || _sessionStartTime == null) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_sessionStartTime!);
    final seconds = duration.inSeconds;

    _sessionStartTime = null;
    _isTimerRunning = false;

    if (seconds <= 0) return;

    try {
      final ref = _firestore
          .collection('events')
          .doc(eventId)
          .collection('screenTime')
          .doc(user.uid);

      await ref.set(
        {
          'userId': user.uid,
          'email': user.email ?? '',
          'totalSeconds': FieldValue.increment(seconds),
          'lastSessionSeconds': seconds,
          'lastSessionEndedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint(
        'AppUsageTrackingService: Saved $seconds seconds for event $eventId.',
      );
    } catch (e) {
      debugPrint('AppUsageTrackingService: Failed to save screen time: $e');
    }
  }

  Future<void> trackAppDownloadOrOpen({
    required String eventId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(user.uid)
          .set(
        {
          'userId': user.uid,
          'email': user.email ?? '',
          'appOpened': true,
          'lastOpenedAt': FieldValue.serverTimestamp(),
          'openCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('AppUsageTrackingService: Failed to track app open: $e');
    }
  }
}