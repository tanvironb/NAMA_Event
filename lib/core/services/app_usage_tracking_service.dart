// lib/core/services/app_usage_tracking_service.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppUsageTrackingService {
  AppUsageTrackingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DateTime? _screenStartTime;

  Future<void> trackAppDownloadOrOpen({
    required String eventId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('appInstalls')
        .doc(user.uid);

    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.set({
        'lastOpenedAt': FieldValue.serverTimestamp(),
        'openCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      return;
    }

    await docRef.set({
      'userId': user.uid,
      'eventId': eventId,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'installedAt': FieldValue.serverTimestamp(),
      'lastOpenedAt': FieldValue.serverTimestamp(),
      'openCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void startScreenTimer() {
    _screenStartTime = DateTime.now();
  }

  Future<void> stopScreenTimerAndSave({
    required String eventId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_screenStartTime == null) return;

    final now = DateTime.now();
    final seconds = now.difference(_screenStartTime!).inSeconds;
    _screenStartTime = null;

    if (seconds <= 0) return;

    final minutes = seconds / 60;

    final docRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('screenTime')
        .doc(user.uid);

    await docRef.set({
      'userId': user.uid,
      'eventId': eventId,
      'seconds': FieldValue.increment(seconds),
      'minutes': FieldValue.increment(minutes),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}